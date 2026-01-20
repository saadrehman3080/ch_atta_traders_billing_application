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

      // Header - centered, large text
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('PAYMENT RECEIPT\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date and time - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - centered heading
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('BILL REFERENCE\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align

      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Get salesman name from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      String displayName = savedSalesmanName ?? salesmanName;

      // Customer name
      bytes.addAll('Customer: ${toTitleCase(customerName)}\n'.codeUnits);

      // Salesman name
      bytes.addAll('Received By: ${toTitleCase(displayName)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Amount received - bold (normal size)
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll(
        'RECEIVED: Rs.${formatCashAmount(amountReceived)}\n'.codeUnits,
      );
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
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

      // Header - centered, large text
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('PARTIAL PAYMENT\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Current date and time - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(DateTime.now())}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Bill Reference - centered heading
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('BILL REFERENCE\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align

      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      final originalDateFormatter = DateFormat('dd MMM yyyy');
      bytes.addAll(
        'Bill Date: ${originalDateFormatter.format(originalBillDate)}\n'
            .codeUnits,
      );
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Get salesman name from shared preferences
      final savedSalesmanName = await AppPreferences.instance.salesmanName;
      String displayName = savedSalesmanName ?? '';

      // Customer name
      bytes.addAll('Customer: ${toTitleCase(customerName)}\n'.codeUnits);

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
        bytes.addAll(
          'Amount Due:      Rs.${formatCashAmount(amountDue)}\n'.codeUnits,
        );
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
        bytes.addAll('Crates Due:      $cratesDue\n'.codeUnits);
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

      // Check if all products are Pepsi products
      final showStoreName = _allProductsArePepsi(products);

      // Store name - centered, large text (only if all products are Pepsi)
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      if (showStoreName) {
        bytes.addAll('CH. ATTA TRADERS\n'.codeUnits);
      }
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date and Bill ID - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(date)}\n'.codeUnits);
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer name
      bytes.addAll('Customer: ${toTitleCase(customerName)}\n'.codeUnits);

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
