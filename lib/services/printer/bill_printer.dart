import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
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

  /// List of Master products
  static const List<String> _masterProducts = [
    'Master Cola 1500ml',
    'Master Cola 2250ml',
    'Master Cola NR 300ml',
    'Master Water 1500ml',
    'Master Water 500ml',
  ];

  /// List of Pepsi products
  static const List<String> _pepsiProducts = [
    'Pepsi 1500ml',
    'Pepsi 250ml RB',
    'Pepsi NR 300ml',
    'Sting 250ml RB',
    'Sting 500ml',
    'Sting NR 300ml',
    'Slice 200ml TP',

    'Revive NR 300ml',
    'Slice 1000ml TP',
    'Pepsi Can 330ml',
    'Sting Can 330ml',
    'Pepsi 1000ml',

    'Pepsi 500ml',
    'Gatorade 500ml',

    'Aquafina 1500ml',
    'Aquafina 500ml',
    'Aquafina 19L',
  ];

  /// Checks if all products are Pepsi products
  static bool _allProductsArePepsi(List<Product> products) {
    for (final product in products) {
      if (!_pepsiProducts.contains(product.name)) {
        return false;
      }
    }
    return true;
  }

  /// Checks if all products are Master products
  static bool _allProductsAreMaster(List<Product> products) {
    for (final product in products) {
      if (!_masterProducts.contains(product.name)) {
        return false;
      }
    }
    return true;
  }

  /// Returns the store name to display based on products
  /// - "CH. ATTA TRADERS" if all products are Pepsi
  /// - "CH. SAAD TRADERS" if all products are Master
  /// - null if products are mixed or from other brands
  static String? _getStoreName(List<Product> products) {
    if (products.isEmpty) return null;
    if (_allProductsArePepsi(products)) return 'CH. ATTA TRADERS';
    if (_allProductsAreMaster(products)) return 'CH. SAAD TRADERS';
    return null;
  }

  /// Returns the phone number for the store based on products
  static String? _getStorePhone(List<Product> products) {
    if (products.isEmpty) return null;
    if (_allProductsArePepsi(products)) return '0309 2000948';
    if (_allProductsAreMaster(products)) return '0331 5348202';
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

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      if (storeName != null) {
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
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('PAYMENT RECEIVED\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date and time - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - left aligned
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );

      // Get salesman name from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      String displayName = savedSalesmanName ?? salesmanName;

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman name
      bytes.addAll('Received By: ${toTitleCase(displayName)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Calculate totals
      final totalItems = BillingCalculations.calculateTotalItems(products);
      final totalCrates = BillingCalculations.calculateTotalCrates(products);
      final grandTotal = BillingCalculations.calculateGrandTotal(products);
      final netAmount = grandTotal - discount;

      // Bill summary section
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('BILL SUMMARY:\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

      bytes.addAll('Total Items:     $totalItems\n'.codeUnits);
      bytes.addAll('Total Crates:    $totalCrates\n'.codeUnits);
      bytes.addAll(
        'Bill Total:      Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
      );
      if (discount > 0) {
        bytes.addAll(
          'Discount:        - Rs.${formatCashAmount(discount)}\n'.codeUnits,
        );
      }
      if (grandTotal != netAmount) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll(
          'Net Amount:      Rs.${formatCashAmount(netAmount)}\n'.codeUnits,
        );
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Only show payment section if the bill is not already fully paid (i.e., amountReceived > 0 or previouslyPaid < netAmount)
      if ((amountReceived > 0) ||
          (previouslyPaid != null && previouslyPaid < netAmount)) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('PAYMENT DETAILS:\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

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

        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll(
          'Received Now:    Rs.${formatCashAmount(amountReceived)}\n'.codeUnits,
        );
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('Remaining:       Rs.0\n'.codeUnits);
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Crates/Empty section
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('EMPTY/CRATES:\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

      // Show previously returned crates if any
      if (previouslyReturnedCrates != null && previouslyReturnedCrates > 0) {
        bytes.addAll(
          'Previously Returned: $previouslyReturnedCrates\n'.codeUnits,
        );
        bytes.addAll('Crates Due:      ${cratesReceived ?? 0}\n'.codeUnits);
      }

      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Returned Now:    ${cratesReceived ?? 0}\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('Remaining:       0\n'.codeUnits);
      bytes.addAll('\n'.codeUnits);

      // Full payment confirmation - centered, bold
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('** BILL CLEARED **\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n'.codeUnits);

      // Footer - center align
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('--------------------------------\n'.codeUnits);
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Payment Confirmed\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
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

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      if (storeName != null) {
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
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on

      // Determine header based on what's being received
      if (amountReceived > 0 && cratesReceived > 0) {
        bytes.addAll('PARTIAL PAYMENT\n'.codeUnits);
      } else if (amountReceived > 0) {
        bytes.addAll('PARTIAL PAYMENT\n'.codeUnits);
      } else if (cratesReceived > 0) {
        bytes.addAll('CRATE RETURN RECEIPT\n'.codeUnits);
      }

      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date and time - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - left aligned
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );

      // Get salesman name from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      String displayName = savedSalesmanName ?? '';

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman name
      if (displayName.isNotEmpty) {
        bytes.addAll('Received By: ${toTitleCase(displayName)}\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Amount section (if received)
      if (amountReceived > 0) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('AMOUNT DETAILS:\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

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
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll(
          'Balance:         Rs.${formatCashAmount(amountBalance)}\n'.codeUnits,
        );
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Crates section (if received)
      if (cratesReceived > 0) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('CRATES (EMPTY) DETAILS:\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

        bytes.addAll('Total Crates:    $totalCrates\n'.codeUnits);
        // Only show Crates Due if it differs from Total Crates (partial returns made)
        if (cratesDue != totalCrates) {
          bytes.addAll('Crates Due:      $cratesDue\n'.codeUnits);
        }
        bytes.addAll('Received:        $cratesReceived\n'.codeUnits);

        final cratesBalance = cratesDue - cratesReceived;
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('Balance:         $cratesBalance\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      bytes.addAll('\n'.codeUnits);

      // Footer - center align
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Payment Recorded\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
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

      // Get store name and phone based on products
      final storeName = _getStoreName(products);
      final storePhone = _getStorePhone(products);

      // Store name - centered, large text (only if all products are from same brand)
      if (storeName != null) {
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
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(date)}\n'.codeUnits);
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer name
      final customerDisplay = customerName.isEmpty
          ? 'Walk-In'
          : toTitleCase(customerName);
      bytes.addAll('Customer: $customerDisplay\n'.codeUnits);

      // Salesman name
      bytes.addAll('Salesman: ${toTitleCase(salesmanName)}\n'.codeUnits);

      // Payment type indicator - bold if credit
      if (paymentType == 'credit') {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('Payment: CREDIT\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      } else {
        bytes.addAll('Payment: Cash\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Items header - bold
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Item                       Total\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Add each product
      for (final product in products) {
        final itemTotal = product.price * product.quantity;

        // Product name (truncate if too long)
        String productName = product.name;
        if (productName.length > 20) {
          productName = '${productName.substring(0, 17)}...';
        }
        bytes.addAll('$productName\n'.codeUnits);

        // Quantity and price details
        final qtyPrice =
            '  ${product.quantity}x @ Rs.${formatCashAmount(product.price)}';
        final totalStr = 'Rs.${formatCashAmount(itemTotal)}';
        final spacing = 32 - qtyPrice.length - totalStr.length;
        final line = qtyPrice + (' ' * (spacing > 0 ? spacing : 1)) + totalStr;
        bytes.addAll('$line\n'.codeUnits);
      }

      bytes.addAll('--------------------------------\n'.codeUnits);

      // Calculate totals
      final totalItems = BillingCalculations.calculateTotalItems(products);
      final grandTotal = BillingCalculations.calculateGrandTotal(products);

      // Total items
      bytes.addAll('Total Items: $totalItems\n'.codeUnits);

      // MT details if user entered any value (including 0)
      if (mtCollected != null && mtRemaining != null) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('MT Collected: $mtCollected\n'.codeUnits);
        bytes.addAll('MT Remaining: $mtRemaining\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      }

      // Subtotal if discount exists
      if (discount > 0) {
        bytes.addAll(
          'Subtotal: Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
        );
        bytes.addAll(
          'Discount: - Rs.${formatCashAmount(discount)}\n'.codeUnits,
        );
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Grand total - large and bold
      final netAmount = grandTotal - discount;
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('TOTAL: Rs.${formatCashAmount(netAmount)}\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\n'.codeUnits);

      // Footer - center align, bold
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Thank you for your business!\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
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
}
