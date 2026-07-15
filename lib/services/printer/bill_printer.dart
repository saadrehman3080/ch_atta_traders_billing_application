import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Result class for print operations
class PrintResult {
  final bool success;
  final String? errorMessage;

  const PrintResult({required this.success, this.errorMessage});

  factory PrintResult.success() => const PrintResult(success: true);
  factory PrintResult.error(String message) =>
      PrintResult(success: false, errorMessage: message);
}

/// Utility class for printing bills using Bluetooth thermal printer
class BillPrinter {
  BillPrinter._();

  /// Checks if all products share the same type
  static bool _allProductsAreType(List<Product> products, String type) {
    return products.every((product) => product.type == type);
  }

  /// Returns the store name to display based on product types
  /// - "CH. ATTA TRADERS" if all products are type 'pepsi'
  /// - "CH. SAAD TRADERS" if all products are type 'masterCola'
  /// - null if products are mixed or type 'others'
  static String? _getStoreName(List<Product> products) {
    if (products.isEmpty) return null;
    if (_allProductsAreType(products, 'pepsi')) return 'CH. ATTA TRADERS';
    if (_allProductsAreType(products, 'masterCola')) return 'CH. SAAD TRADERS';
    return null;
  }

  /// Returns the phone number for the store based on product types
  static String? _getStorePhone(List<Product> products) {
    if (products.isEmpty) return null;
    if (_allProductsAreType(products, 'pepsi')) return '0309 2000948';
    if (_allProductsAreType(products, 'masterCola')) return '0331 5348202';
    return null;
  }

  /// Prints a payment receipt (without product details)
  ///
  /// This is used when marking a credit bill as complete to give customer
  /// a receipt confirming payment was received.
  static Future<PrintResult> printPaymentReceipt({
    required String billId,
    required String customerName,
    required DateTime originalBillDate,
    required int amountReceived,
    required String salesmanName,
    required List<Product> products,
    required int discount,
    int? previouslyPaid, // Amount already paid before this payment
    int? cratesReceived, // Crates returned with this payment
    int?
    previouslyReturnedCrates, // Crates already returned before this payment
    bool isCashAlreadyPaid =
        false, // True if cash was already paid (only crates were pending)
  }) async {
    try {
      // Check if printer is connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      // Check anonymous print mode
      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      // Skip business name in anonymous print mode
      if (storeName != null && !isAnonymousPrint) {
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
        bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
        bytes.addAll('$storeName\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        if (storePhone != null) {
          bytes.addAll('$storePhone\n'.codeUnits);
        }
        bytes.addAll('\n'.codeUnits);
      }

      // Header - centered
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('PAYMENT RECEIVED\n'.codeUnits);
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date (and time if not anonymous) - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        final dateFormatter = DateFormat('dd MMM yyyy');
        bytes.addAll(
          'Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits,
        );
      } else {
        final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
        bytes.addAll(
          'Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - left aligned
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );

      // Get salesman name/ID from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      final savedSalesmanId = await AppPreferences.instance.salesmanId;
      String displayName = savedSalesmanName ?? salesmanName;

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman: show ID in anonymous mode, name otherwise
      if (isAnonymousPrint) {
        bytes.addAll('Received By: ${savedSalesmanId ?? ''}\n'.codeUnits);
      } else {
        bytes.addAll('Received By: ${toTitleCase(displayName)}\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Calculate totals
      final totalItems = BillingCalculations.calculateTotalItems(products);
      final totalCrates = BillingCalculations.calculateTotalCrates(products);
      final grandTotal = BillingCalculations.calculateGrandTotal(products);
      final netAmount = grandTotal - discount;

      // Bill summary section
      bytes.addAll('BILL SUMMARY:\n'.codeUnits);

      bytes.addAll(
        'Total ${totalItems == 1 ? 'Item' : 'Items'}:     $totalItems\n'
            .codeUnits,
      );
      bytes.addAll('Total Crates:    $totalCrates\n'.codeUnits);
      bytes.addAll(
        'Bill Total:      Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
      );
      if (discount > 0) {
        bytes.addAll(
          'Discount:        - Rs.${formatCashAmount(discount)}\n'.codeUnits,
        );
        bytes.addAll(
          'Net Amount:      Rs.${formatCashAmount(netAmount)}\n'.codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Payment section
      if (isCashAlreadyPaid) {
        // Cash was already paid at time of sale - only crates were pending
        bytes.addAll('PAYMENT DETAILS:\n'.codeUnits);
        bytes.addAll(
          'Cash Already Paid: Rs.${formatCashAmount(netAmount)}\n'.codeUnits,
        );
        bytes.addAll('--------------------------------\n'.codeUnits);
      } else if ((amountReceived > 0) ||
          (previouslyPaid != null && previouslyPaid < netAmount)) {
        bytes.addAll('PAYMENT DETAILS:\n'.codeUnits);

        // Show previously paid if there was a prior payment
        if (previouslyPaid != null && previouslyPaid > 0) {
          bytes.addAll(
            'Previously Paid: Rs.${formatCashAmount(previouslyPaid)}\n'
                .codeUnits,
          );
          bytes.addAll(
            'Amount Due:      Rs.${formatCashAmount(amountReceived)}\n'
                .codeUnits,
          );
        }

        bytes.addAll(
          'Received Now:    Rs.${formatCashAmount(amountReceived)}\n'.codeUnits,
        );
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Crates/Empty section
      // Only show EMPTY/CRATES section if there are any returned/received crates
      // Do not show when total crates exist but nothing was returned/received.
      final int cratesNow = cratesReceived ?? 0;
      final int cratesPrev = previouslyReturnedCrates ?? 0;
      final bool hasCratesToShow = (cratesNow + cratesPrev) > 0;

      if (hasCratesToShow) {
        bytes.addAll('EMPTY/CRATES:\n'.codeUnits);

        // Show previously returned crates if any
        if (cratesPrev > 0) {
          bytes.addAll('Previously Returned: $cratesPrev\n'.codeUnits);
        }

        // Show crates returned now if any
        if (cratesNow > 0) {
          bytes.addAll('Returned Now:    $cratesNow\n'.codeUnits);
        }
        bytes.addAll('\n'.codeUnits);
      }

      // Full payment confirmation - centered
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('** BILL CLEARED **\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n'.codeUnits);

      // Footer - center align
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('--------------------------------\n'.codeUnits);
      bytes.addAll('Payment Confirmed\n'.codeUnits);
      bytes.addAll('Thank you!\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n\n\n'.codeUnits);

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        return PrintResult.success();
      } else {
        return PrintResult.error('Failed to print receipt');
      }
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return PrintResult.error('Error printing receipt: ${e.toString()}');
    }
  }

  /// Prints a partial payment receipt showing amounts and crates received
  ///
  /// This is used when recording a partial payment (cash/crates) to give customer
  /// a receipt showing what was received and remaining balance.
  static Future<PrintResult> printPartialPaymentReceipt({
    required String billId,
    required String customerName,
    required DateTime originalBillDate,
    required int billTotal,
    required int amountDue,
    required int amountReceived,
    required int totalCrates,
    required int cratesDue,
    required int cratesReceived,
    required List<Product> products,
  }) async {
    try {
      // Check if printer is connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      // Check anonymous print mode
      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      // Skip business name in anonymous print mode
      if (storeName != null && !isAnonymousPrint) {
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
        bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
        bytes.addAll('$storeName\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        if (storePhone != null) {
          bytes.addAll('$storePhone\n'.codeUnits);
        }
        bytes.addAll('\n'.codeUnits);
      }

      // Header - centered (dynamic based on what's being received)
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align

      // Determine header based on what's being received
      if (amountReceived > 0 && cratesReceived > 0) {
        bytes.addAll('PARTIAL PAYMENT\n'.codeUnits);
      } else if (amountReceived > 0) {
        bytes.addAll('PARTIAL PAYMENT\n'.codeUnits);
      } else if (cratesReceived > 0) {
        bytes.addAll('CRATE RETURN RECEIPT\n'.codeUnits);
      }
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date (and time if not anonymous) - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        final dateFormatter = DateFormat('dd MMM yyyy');
        bytes.addAll(
          'Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits,
        );
      } else {
        final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
        bytes.addAll(
          'Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - left aligned
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );

      // Get salesman name/ID from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      final savedSalesmanId = await AppPreferences.instance.salesmanId;
      String displayName = savedSalesmanName ?? '';

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In Customer'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman: show ID in anonymous mode, name otherwise
      if (isAnonymousPrint) {
        bytes.addAll('Received By: ${savedSalesmanId ?? ''}\n'.codeUnits);
      } else if (displayName.isNotEmpty) {
        bytes.addAll('Received By: ${toTitleCase(displayName)}\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Amount section (if received)
      if (amountReceived > 0) {
        bytes.addAll('AMOUNT DETAILS:\n'.codeUnits);

        bytes.addAll(
          'Bill Total:      Rs.${formatCashAmount(billTotal)}\n'.codeUnits,
        );
        // Only show Amount Due if it differs from Bill Total (partial payments made)
        if (amountDue != billTotal) {
          bytes.addAll(
            'Amount Due:      Rs.${formatCashAmount(amountDue)}\n'.codeUnits,
          );
        }
        bytes.addAll(
          'Received:        Rs.${formatCashAmount(amountReceived)}\n'.codeUnits,
        );

        final amountBalance = amountDue - amountReceived;
        if (amountBalance > 0) {
          bytes.addAll(
            'Balance:         Rs.${formatCashAmount(amountBalance)}\n'
                .codeUnits,
          );
        }
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Crates section (if received)
      if (cratesReceived > 0) {
        bytes.addAll('CRATES (EMPTY) DETAILS:\n'.codeUnits);

        bytes.addAll('Total Crates:    $totalCrates\n'.codeUnits);
        // Only show Crates Due if it differs from Total Crates (partial returns made)
        if (cratesDue != totalCrates) {
          bytes.addAll('Crates Due:      $cratesDue\n'.codeUnits);
        }
        bytes.addAll('Received:        $cratesReceived\n'.codeUnits);

        final cratesBalance = cratesDue - cratesReceived;
        if (cratesBalance > 0) {
          bytes.addAll('Balance:         $cratesBalance\n'.codeUnits);
        }
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      bytes.addAll('\n'.codeUnits);

      // Footer - center align
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('Payment Recorded\n'.codeUnits);
      bytes.addAll('Thank you!\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n\n\n'.codeUnits);

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        return PrintResult.success();
      } else {
        return PrintResult.error('Failed to print receipt');
      }
    } catch (e) {
      debugPrint('Error printing partial payment receipt: $e');
      return PrintResult.error('Error printing receipt: ${e.toString()}');
    }
  }

  /// Prints a compact receipt for a bulk payment (cash received against
  /// multiple credit bills for one customer).
  static Future<PrintResult> printBulkPaymentReceipt({
    required String customerName,
    required int amountReceived,
    required int totalBills,
    required int totalAmountDue,
    required int previouslyPaid,
    required int remainingAfter,
    int totalPendingCrates = 0,
    List<({String billId, int amount, DateTime date})> billDetails = const [],
  }) async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;

      // Header
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x01'.codeUnits); // Double height
      bytes.addAll('PAYMENT RECEIVED\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('(Bulk Payment)\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}\n'
              .codeUnits,
        );
      } else {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}\n'
              .codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman
      if (isAnonymousPrint) {
        final id = await AppPreferences.instance.salesmanId;
        bytes.addAll('Received By: ${id ?? ''}\n'.codeUnits);
      } else {
        final name = await AppPreferences.instance.salesmanName;
        if (name != null && name.isNotEmpty) {
          bytes.addAll('Received By: ${toTitleCase(name)}\n'.codeUnits);
        }
      }

      bytes.addAll('Bills:    $totalBills\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill details
      if (billDetails.isNotEmpty) {
        bytes.addAll('BILLS:\n'.codeUnits);
        final dateFmt = DateFormat('dd MMM');
        for (final bill in billDetails) {
          final shortId = truncateBillId(bill.billId);
          bytes.addAll(
            '#$shortId ${dateFmt.format(bill.date)} Rs.${formatCashAmount(bill.amount)}\n'
                .codeUnits,
          );
        }
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Amount details
      bytes.addAll('AMOUNT DETAILS:\n'.codeUnits);
      bytes.addAll(
        'Total Due:       Rs.${formatCashAmount(totalAmountDue)}\n'.codeUnits,
      );
      if (previouslyPaid > 0) {
        bytes.addAll(
          'Previously Paid: Rs.${formatCashAmount(previouslyPaid)}\n'.codeUnits,
        );
      }
      bytes.addAll(
        'Received Now:    Rs.${formatCashAmount(amountReceived)}\n'.codeUnits,
      );
      bytes.addAll('--------------------------------\n'.codeUnits);

      // MT details (only when pending crates exist)
      if (totalPendingCrates > 0) {
        bytes.addAll('MT DETAILS:\n'.codeUnits);
        bytes.addAll('MT Pending:      $totalPendingCrates\n'.codeUnits);
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      if (remainingAfter == 0) {
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center
        bytes.addAll('** FULLY PAID **\n'.codeUnits);
        bytes.addAll('\x1B\x61\x00'.codeUnits); // Left
      } else {
        bytes.addAll(
          'Remaining:       Rs.${formatCashAmount(remainingAfter)}\n'.codeUnits,
        );
      }

      // Footer
      bytes.addAll('\n'.codeUnits);
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center
      bytes.addAll('Payment Confirmed\n'.codeUnits);
      bytes.addAll('Thank you!\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left
      bytes.addAll('\n\n\n'.codeUnits);

      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result
          ? PrintResult.success()
          : PrintResult.error('Failed to print receipt');
    } catch (e) {
      debugPrint('Error printing bulk payment receipt: $e');
      return PrintResult.error('Error printing receipt: ${e.toString()}');
    }
  }

  /// Prints a customer account statement focused on pending bills, pending
  /// amount and optional payment history.
  static Future<PrintResult> printBulkPaymentAccountStatement({
    required String customerName,
    required int totalBills,
    required int totalAmountDue,
    required int totalPaid,
    required int remainingBillsCount,
    required int remainingAmount,
    required int totalPendingCrates,
    List<CreditHistory> allBills = const [],
    List<({DateTime date, int amount, String source, String? billId})>
        paymentEntries =
        const [],
    bool includePaymentHistory = true,
  }) async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;

      List<int> bytes = [];

      // Header
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x01'.codeUnits); // Double height
      bytes.addAll('ACCOUNT STATEMENT\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}\n'
              .codeUnits,
        );
      } else {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}\n'
              .codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      if (isAnonymousPrint) {
        final id = await AppPreferences.instance.salesmanId;
        bytes.addAll('Salesman: ${id ?? ''}\n'.codeUnits);
      } else {
        final name = await AppPreferences.instance.salesmanName;
        if (name != null && name.isNotEmpty) {
          bytes.addAll('Salesman: ${toTitleCase(name)}\n'.codeUnits);
        }
      }

      bytes.addAll('Bills on Account: $totalBills\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Account-level summary
      bytes.addAll('ACCOUNT SUMMARY:\n'.codeUnits);
      bytes.addAll(
        'Total Due:     Rs.${formatCashAmount(totalAmountDue)}\n'.codeUnits,
      );
      bytes.addAll(
        'Paid:          Rs.${formatCashAmount(totalPaid)}\n'.codeUnits,
      );
      bytes.addAll(
        'Outstanding:   Rs.${formatCashAmount(remainingAmount)}\n'.codeUnits,
      );
      bytes.addAll('Pending Bills: $remainingBillsCount\n'.codeUnits);
      if (totalPendingCrates > 0) {
        bytes.addAll('MT Pending:    $totalPendingCrates\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Remaining bills summary
      final pendingBills =
          allBills.where((b) => b.amountDue > 0 || b.cratesDue > 0).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      bytes.addAll('REMAINING BILLS:\n'.codeUnits);
      if (pendingBills.isEmpty) {
        bytes.addAll('No pending bills.\n'.codeUnits);
      } else {
        final dateFmt = DateFormat('dd MMM');
        const maxLines = 8;
        final displayBills = pendingBills.take(maxLines).toList();
        for (final bill in displayBills) {
          final id = truncateBillId(bill.billId);
          bytes.addAll(
            '#$id ${dateFmt.format(bill.date)} Rs.${formatCashAmount(bill.amountDue)}\n'
                .codeUnits,
          );
          if (bill.cratesDue > 0) {
            bytes.addAll('  MT Due: ${bill.cratesDue}\n'.codeUnits);
          }
        }
        final hiddenCount = pendingBills.length - displayBills.length;
        if (hiddenCount > 0) {
          bytes.addAll('...and $hiddenCount more bill(s)\n'.codeUnits);
        }
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      if (includePaymentHistory) {
        final sortedEntries =
            List<
                ({DateTime date, int amount, String source, String? billId})
              >.from(paymentEntries)
              ..sort((a, b) => b.date.compareTo(a.date));

        bytes.addAll('PAYMENT HISTORY:\n'.codeUnits);
        if (sortedEntries.isEmpty) {
          bytes.addAll('No payment history available.\n'.codeUnits);
        } else {
          final dateFmt = DateFormat('dd MMM, hh:mm a');
          const maxEntries = 10;
          final displayEntries = sortedEntries.take(maxEntries).toList();
          for (final entry in displayEntries) {
            final sourceLabel = switch (entry.source) {
              'bulk' => 'Payment',
              'bill partial' => 'Partial',
              _ => entry.source,
            };
            final amount = 'Rs.${formatCashAmount(entry.amount)}';
            bytes.addAll('${dateFmt.format(entry.date)}\n'.codeUnits);
            if (entry.billId != null && entry.billId!.isNotEmpty) {
              final billShortId = truncateBillId(entry.billId!);
              bytes.addAll(
                '  $sourceLabel: $amount  #$billShortId\n'.codeUnits,
              );
            } else {
              bytes.addAll('  $sourceLabel: $amount\n'.codeUnits);
            }
          }
          final hidden = sortedEntries.length - displayEntries.length;
          if (hidden > 0) {
            bytes.addAll('...and $hidden older entry(s)\n'.codeUnits);
          }

          final collectedTotal = sortedEntries.fold<int>(
            0,
            (sum, e) => sum + e.amount,
          );
          bytes.addAll(
            'Collected Total: Rs.${formatCashAmount(collectedTotal)}\n'
                .codeUnits,
          );
        }

        bytes.addAll('\n'.codeUnits);
      }

      // Customer-facing outstanding alert
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center
      bytes.addAll('--------------------------------\n'.codeUnits);
      if (remainingAmount > 0 || pendingBills.isNotEmpty) {
        bytes.addAll('** NOTICE **\n'.codeUnits);
        bytes.addAll(
          '${remainingBillsCount > 1 ? '$remainingBillsCount bills' : '1 bill'} still pending\n'
              .codeUnits,
        );
        bytes.addAll(
          'Rs.${formatCashAmount(remainingAmount)} outstanding\n'.codeUnits,
        );
        bytes.addAll('Please clear pending amount.\n'.codeUnits);
      } else {
        bytes.addAll('** ACCOUNT SETTLED **\n'.codeUnits);
        bytes.addAll('All bills cleared. Thank you!\n'.codeUnits);
      }
      bytes.addAll('Thank you!\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left
      bytes.addAll('\n\n\n'.codeUnits);

      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result
          ? PrintResult.success()
          : PrintResult.error('Failed to print receipt');
    } catch (e) {
      debugPrint('Error printing bulk payment account statement: $e');
      return PrintResult.error('Error printing receipt: ${e.toString()}');
    }
  }

  /// Prints a compact receipt for an MT (empty crate) return recorded via
  /// bulk payment.
  static Future<PrintResult> printBulkCrateReturnReceipt({
    required String customerName,
    required int cratesReturned,
    required int totalCratesBefore,
    required int cratesRemainingAfter,
    List<({String billId, int crates, DateTime date})> billDetails = const [],
  }) async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;

      // Header
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x01'.codeUnits); // Double height
      bytes.addAll('MT RECEIVED\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('(Crate Return)\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}\n'
              .codeUnits,
        );
      } else {
        bytes.addAll(
          'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}\n'
              .codeUnits,
        );
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman
      if (isAnonymousPrint) {
        final id = await AppPreferences.instance.salesmanId;
        bytes.addAll('Received By: ${id ?? ''}\n'.codeUnits);
      } else {
        final name = await AppPreferences.instance.salesmanName;
        if (name != null && name.isNotEmpty) {
          bytes.addAll('Received By: ${toTitleCase(name)}\n'.codeUnits);
        }
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill details (only bills that had/have crates)
      final billsWithCrates = billDetails.where((b) => b.crates > 0).toList();
      if (billsWithCrates.isNotEmpty) {
        bytes.addAll('BILLS WITH PENDING CRATES:\n'.codeUnits);
        final dateFmt = DateFormat('dd MMM');
        for (final bill in billsWithCrates) {
          final shortId = truncateBillId(bill.billId);
          bytes.addAll(
            '#$shortId ${dateFmt.format(bill.date)} x${bill.crates} crates\n'
                .codeUnits,
          );
        }
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Crate details
      bytes.addAll('EMPTY/CRATES DETAILS:\n'.codeUnits);
      bytes.addAll('Total Due:       $totalCratesBefore\n'.codeUnits);
      bytes.addAll('Returned Now:    $cratesReturned\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      if (cratesRemainingAfter == 0) {
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center
        bytes.addAll('** ALL CRATES RETURNED **\n'.codeUnits);
        bytes.addAll('\x1B\x61\x00'.codeUnits); // Left
      } else {
        bytes.addAll('Still Pending:   $cratesRemainingAfter\n'.codeUnits);
      }

      // Footer
      bytes.addAll('\n'.codeUnits);
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center
      bytes.addAll('MT Return Confirmed\n'.codeUnits);
      bytes.addAll('Thank you!\n'.codeUnits);
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left
      bytes.addAll('\n\n\n'.codeUnits);

      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result
          ? PrintResult.success()
          : PrintResult.error('Failed to print receipt');
    } catch (e) {
      debugPrint('Error printing bulk crate return receipt: $e');
      return PrintResult.error('Error printing receipt: ${e.toString()}');
    }
  }

  /// Prints a bill with the given details
  ///
  /// Returns a [PrintResult] indicating success or failure with error message
  static Future<PrintResult> printBill({
    required String billId,
    required String customerName,
    required DateTime date,
    required List<Product> products,
    required int discount,
    required String salesmanName,
    required String paymentType,
    int? mtCollected,
    int? mtRemaining,
    int? partialPayment,
    bool showDuplicateLabel = false,
    bool isPendingSync = false,
    List<PartialPayment>? paymentHistory,
    bool includeSubtypeDetails = false,
  }) async {
    try {
      // Check if printer is connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      // Check anonymous print mode
      final isAnonymousPrint =
          await AppPreferences.instance.isAnonymousPrintEnabled;
      final savedSalesmanId = await AppPreferences.instance.salesmanId;

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      // Skip business name in anonymous print mode
      if (storeName != null && !isAnonymousPrint) {
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
        bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
        bytes.addAll('$storeName\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        if (storePhone != null) {
          bytes.addAll('$storePhone\n'.codeUnits);
        }
        bytes.addAll('\n'.codeUnits);
      }

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date and Bill ID - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      if (isAnonymousPrint) {
        final dateFormatter = DateFormat('dd MMM yyyy');
        bytes.addAll('Date: ${dateFormatter.format(date)}\n'.codeUnits);
      } else {
        final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
        bytes.addAll('Date: ${dateFormatter.format(date)}\n'.codeUnits);
      }
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman: show ID in anonymous mode or when products are mixed/others, name otherwise
      if (isAnonymousPrint || storeName == null) {
        bytes.addAll('Salesman: ${savedSalesmanId ?? ''}\n'.codeUnits);
      } else {
        bytes.addAll('Salesman: ${toTitleCase(salesmanName)}\n'.codeUnits);
      }

      // Payment type indicator
      if (paymentType == 'credit') {
        bytes.addAll('Payment: CREDIT\n'.codeUnits);
      } else {
        bytes.addAll('Payment: Cash\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Items header
      bytes.addAll('Item                       Total\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Add each product
      for (final product in products) {
        final itemTotal = product.price * product.quantity;

        // Product name (wrap if too long)
        final productNameLines = _wrapText(product.name, 32, indent: '  ');
        for (final line in productNameLines) {
          bytes.addAll('$line\n'.codeUnits);
        }

        // Quantity and price details
        final qtyPrice =
            '  ${product.quantity}x @ Rs.${formatCashAmount(product.price)}';
        final totalStr = 'Rs.${formatCashAmount(itemTotal)}';
        final spacing = 32 - qtyPrice.length - totalStr.length;
        final line = qtyPrice + (' ' * (spacing > 0 ? spacing : 1)) + totalStr;
        bytes.addAll('$line\n'.codeUnits);

        // Print subtype/variant breakdown if requested
        if (includeSubtypeDetails && product.hasSubtypes) {
          final subtypeEntries = product.subtypeQuantities.entries
              .where((e) => e.value > 0)
              .map((e) => '${e.key}(${e.value})')
              .toList();

          if (subtypeEntries.isNotEmpty) {
            // Wrap variants into a few compact lines so receipt isn't too tall.
            // Aim for ~26 chars per line (58mm printer width).
            const maxLineLength = 26;
            var line = '  Variants: ';

            for (final part in subtypeEntries) {
              final candidate = line.endsWith(' ')
                  ? '$line$part'
                  : '$line, $part';
              if (candidate.length > maxLineLength &&
                  line.trim() != 'Variants:') {
                bytes.addAll('$line\n'.codeUnits);
                line = '    $part';
              } else {
                line = candidate;
              }
            }

            bytes.addAll('$line\n'.codeUnits);
          }
        }

        // Consistent small gap after every product when subtype details are shown
        if (includeSubtypeDetails) {
          bytes.addAll('\x1B\x4A\x06'.codeUnits);
        }
      }

      bytes.addAll('--------------------------------\n'.codeUnits);

      // Calculate totals
      final totalItems = BillingCalculations.calculateTotalItems(products);
      final grandTotal = BillingCalculations.calculateGrandTotal(products);

      // Total items
      bytes.addAll(
        'Total ${totalItems == 1 ? 'Item' : 'Items'}: $totalItems\n'.codeUnits,
      );

      // MT details if user entered any value (including 0)
      if (mtCollected != null && mtRemaining != null) {
        bytes.addAll('MT Collected: $mtCollected\n'.codeUnits);
        if (mtRemaining > 0) {
          bytes.addAll('MT Remaining: $mtRemaining\n'.codeUnits);
        }
      }

      // Subtotal and discount if discount exists
      final netAmount = grandTotal - discount;
      if (discount > 0) {
        bytes.addAll(
          'Subtotal: Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
        );
        bytes.addAll(
          'Discount: - Rs.${formatCashAmount(discount)}\n'.codeUnits,
        );
      }

      // Partial payment section for credit bills
      if (partialPayment != null && partialPayment > 0) {
        bytes.addAll('--------------------------------\n'.codeUnits);
        bytes.addAll(
          'Total:           Rs.${formatCashAmount(netAmount)}\n'.codeUnits,
        );
        bytes.addAll(
          'Now Paying:      Rs.${formatCashAmount(partialPayment)}\n'.codeUnits,
        );
        final remaining = netAmount - partialPayment;
        bytes.addAll(
          'Remaining:       Rs.${formatCashAmount(remaining)}\n'.codeUnits,
        );
        bytes.addAll('\n'.codeUnits);
      } else {
        // Grand total - large and bold (only when no partial payment)
        // For 5+ digit amounts, use double-height only (not double-width)
        // to prevent overflow on 58mm printers (~16 chars at double size)
        final formattedNet = formatCashAmount(netAmount);
        final totalLine = 'TOTAL: Rs.$formattedNet';
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        if (totalLine.length > 16) {
          // Double-height only (normal width) for long totals
          bytes.addAll('\x1D\x21\x01'.codeUnits);
        } else {
          // Double width + double height for short totals
          bytes.addAll('\x1D\x21\x11'.codeUnits);
        }
        bytes.addAll('$totalLine\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('\n'.codeUnits);
      }

      // Payment History section (for reprinted credit bills with partial payments)
      if (paymentHistory != null && paymentHistory.isNotEmpty) {
        bytes.addAll('--------------------------------\n'.codeUnits);
        bytes.addAll('PAYMENT HISTORY:\n'.codeUnits);

        final paymentDateFmt = DateFormat('dd MMM yyyy');
        for (final payment in paymentHistory) {
          final dateStr = paymentDateFmt.format(payment.date);
          final amtStr = 'Rs.${formatCashAmount(payment.amount)}';
          bytes.addAll('Paid $amtStr on $dateStr\n'.codeUnits);
        }

        final totalPaid = paymentHistory.fold<int>(
          0,
          (sum, p) => sum + p.amount,
        );
        final remaining = netAmount - totalPaid;
        if (remaining > 0) {
          bytes.addAll(
            'Remaining: Rs.${formatCashAmount(remaining)}\n'.codeUnits,
          );
        } else {
          bytes.addAll('Fully Paid\n'.codeUnits);
        }
        bytes.addAll('\n'.codeUnits);
      }

      // Footer - center align
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align

      bytes.addAll('Thank you for your business!\n'.codeUnits);

      if (showDuplicateLabel) {
        bytes.addAll('\n'.codeUnits);
        bytes.addAll('--------------------------------\n'.codeUnits);
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        // "Duplicate Bill" = 14 chars → double width + height (same as short TOTAL)
        bytes.addAll('\x1D\x21\x11'.codeUnits);
        bytes.addAll('Duplicate Bill\n'.codeUnits);
        // "For Reference Only" = 18 chars → double height only (same as long TOTAL)
        bytes.addAll('\x1D\x21\x01'.codeUnits);
        bytes.addAll('For Reference Only\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      }

      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n\n\n'.codeUnits);

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        return PrintResult.success();
      } else {
        return PrintResult.error('Failed to print bill');
      }
    } catch (e) {
      debugPrint('Error printing bill: $e');
      return PrintResult.error('Error printing bill: ${e.toString()}');
    }
  }

  /// Prints a rate list for selected product types
  ///
  /// [products] - All available products
  /// [selectedTypes] - Which types to include ('pepsi', 'masterCola', 'others', 'all')
  static Future<PrintResult> printRateList({
    required List<Product> products,
    required List<String> selectedTypes,
  }) async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        return PrintResult.error(
          'No printer connected. Please connect a printer first.',
        );
      }

      List<int> bytes = [];

      final dateFormatter = DateFormat('dd MMM yyyy');
      final todayStr = dateFormatter.format(DateTime.now());

      // "All Products" mode — single receipt, no business name
      final isAllMode = selectedTypes.contains('all');

      if (isAllMode) {
        // Centered title
        bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
        bytes.addAll('RATE LIST\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('\n'.codeUnits);

        // Date - bold
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('\x1D\x21\x01'.codeUnits); // Double height
        bytes.addAll('Date: $todayStr\n'.codeUnits);
        bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('\n'.codeUnits);

        // Print all available products grouped by type
        for (final type in ['pepsi', 'masterCola', 'others']) {
          final typeProducts = products
              .where((p) => p.type == type && p.isAvailable)
              .toList();
          if (typeProducts.isEmpty) continue;

          bytes.addAll('--------------------------------\n'.codeUnits);
          bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
          bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
          bytes.addAll('${_typeDisplayName(type)}\n'.codeUnits);
          bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
          bytes.addAll('--------------------------------\n'.codeUnits);

          bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
          _addProductRows(bytes, typeProducts);
          bytes.addAll('\n'.codeUnits);
        }
      } else {
        // Per-type mode — each type gets its own header
        for (final type in selectedTypes) {
          final typeProducts = products
              .where((p) => p.type == type && p.isAvailable)
              .toList();
          if (typeProducts.isEmpty) continue;

          // Business name header (matches checkout logic)
          final storeName = _getStoreNameForType(type);
          final storePhone = _getStorePhoneForType(type);

          bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
          if (storeName != null) {
            bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
            bytes.addAll('$storeName\n'.codeUnits);
            bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
            if (storePhone != null) {
              bytes.addAll('$storePhone\n'.codeUnits);
            }
            bytes.addAll('\n'.codeUnits);
          } else {
            // Others — no business name, just a title
            bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
            bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
            bytes.addAll('RATE LIST\n'.codeUnits);
            bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
            bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
            bytes.addAll('\n'.codeUnits);
          }

          // Date - bold
          bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
          bytes.addAll('\x1D\x21\x01'.codeUnits); // Double height
          bytes.addAll('Date: $todayStr\n'.codeUnits);
          bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
          bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
          bytes.addAll('\n'.codeUnits);

          // Section header (skip for 'others' — no category header needed)
          if (type != 'others') {
            bytes.addAll('--------------------------------\n'.codeUnits);
            bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
            bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
            bytes.addAll('${_typeDisplayName(type)}\n'.codeUnits);
            bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
            bytes.addAll('--------------------------------\n'.codeUnits);
          }

          // Product rows
          bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
          _addProductRows(bytes, typeProducts);
          bytes.addAll('\n'.codeUnits);
        }
      }

      // Disclaimer at the end
      bytes.addAll('--------------------------------\n'.codeUnits);
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('These are today\'s rates and\n'.codeUnits);
      bytes.addAll('are subject to change.\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n\n\n'.codeUnits);

      final result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        return PrintResult.success();
      } else {
        return PrintResult.error('Failed to print rate list');
      }
    } catch (e) {
      debugPrint('Error printing rate list: $e');
      return PrintResult.error('Error printing rate list: ${e.toString()}');
    }
  }

  /// Returns store name for a single product type
  static String? _getStoreNameForType(String type) {
    switch (type) {
      case 'pepsi':
        return 'CH. ATTA TRADERS';
      case 'masterCola':
        return 'CH. SAAD TRADERS';
      default:
        return null;
    }
  }

  /// Returns store phone for a single product type
  static String? _getStorePhoneForType(String type) {
    switch (type) {
      case 'pepsi':
        return '0309 2000948';
      case 'masterCola':
        return '0331 5348202';
      default:
        return null;
    }
  }

  /// Maps type key to display name
  static String _typeDisplayName(String type) {
    switch (type) {
      case 'pepsi':
        return 'PEPSI PRODUCTS';
      case 'masterCola':
        return 'MASTER COLA PRODUCTS';
      case 'others':
        return 'OTHER PRODUCTS';
      default:
        return type.toUpperCase();
    }
  }

  /// Wraps a text string to multiple lines for thermal receipts.
  ///
  /// - [maxLineLength]: max characters per line (printer width).
  /// - [indent]: string to prefix lines after the first for readability.
  static List<String> _wrapText(
    String text,
    int maxLineLength, {
    String indent = '',
  }) {
    if (maxLineLength <= 0) return [text];

    final List<String> lines = [];
    final words = text.split(RegExp(r'\s+'));

    String current = '';
    var allowedLength = maxLineLength;

    for (final word in words) {
      if (current.isEmpty) {
        if (word.length > allowedLength) {
          // Break long words
          var remaining = word;
          while (remaining.length > allowedLength) {
            lines.add(remaining.substring(0, allowedLength));
            remaining = remaining.substring(allowedLength);
            // Subsequent lines should account for indent
            allowedLength = maxLineLength - indent.length;
          }
          current = remaining;
        } else {
          current = word;
        }
      } else if (current.length + 1 + word.length <= allowedLength) {
        current = '$current $word';
      } else {
        lines.add(current);
        // After first line, apply indent (affects allowed width)
        allowedLength = maxLineLength - indent.length;
        if (word.length > allowedLength) {
          var remaining = word;
          while (remaining.length > allowedLength) {
            lines.add('$indent${remaining.substring(0, allowedLength)}');
            remaining = remaining.substring(allowedLength);
          }
          current = remaining;
        } else {
          current = word;
        }
      }
    }

    if (current.isNotEmpty) {
      if (lines.isEmpty) {
        lines.add(current);
      } else {
        lines.add('$indent$current');
      }
    }

    return lines;
  }

  /// Adds formatted product rows to byte list
  static void _addProductRows(List<int> bytes, List<Product> typeProducts) {
    for (final product in typeProducts) {
      String productName = product.name;
      if (productName.length > 22) {
        productName = '${productName.substring(0, 19)}...';
      }
      final priceStr = 'Rs.${formatCashAmount(product.price)}';
      final spacing = 32 - productName.length - priceStr.length;
      final line = productName + (' ' * (spacing > 0 ? spacing : 1)) + priceStr;
      bytes.addAll('$line\n'.codeUnits);
    }
  }
}
