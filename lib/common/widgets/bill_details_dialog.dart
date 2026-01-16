import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';

class BillDetailsDialog extends StatefulWidget {
  final BillBase bill;
  final Color accentColor;

  const BillDetailsDialog({
    super.key,
    required this.bill,
    this.accentColor = AppColors.pepsiBlue,
  });

  @override
  State<BillDetailsDialog> createState() => _BillDetailsDialogState();
}

class _BillDetailsDialogState extends State<BillDetailsDialog> {
  bool _isPrinting = false;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  // Check if this is a paid bill (SaleHistory is always paid, CreditHistory checks isPaid)
  bool get _isPaid => widget.bill is CreditHistory
      ? (widget.bill as CreditHistory).isPaid
      : true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollable);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollable());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollable);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollable() {
    if (_scrollController.hasClients) {
      final isScrollable = _scrollController.position.maxScrollExtent > 0;
      if (isScrollable != _isScrollable) {
        setState(() {
          _isScrollable = isScrollable;
        });
      }
    }
  }

  Future<void> _printBill() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      // Get salesman name from SharedPreferences
      final salesmanName = await AppPreferences.instance.salesmanName;
      if (salesmanName == null || salesmanName.isEmpty) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Salesman name not found. Please login again.',
            type: SnackBarType.error,
          );
        }
        setState(() {
          _isPrinting = false;
        });
        return;
      }

      // Check if printer is connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'No printer connected. Please connect a printer first.',
            type: SnackBarType.error,
          );
        }
        setState(() {
          _isPrinting = false;
        });
        return;
      }

      List<int> bytes = [];

      // Store name - centered, large text
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('CH. ATTA TRADERS\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date and Bill ID - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll(
        'Date: ${dateFormatter.format(widget.bill.date)}\n'.codeUnits,
      );
      bytes.addAll(
        'Bill ID: ${truncateBillId(widget.bill.billId)}\n'.codeUnits,
      );
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer name - bold
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll(
        'Customer: ${toTitleCase(widget.bill.customerName)}\n'.codeUnits,
      );
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

      // Salesman name
      bytes.addAll('Salesman: ${toTitleCase(salesmanName)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Items header - bold
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Item                Qty    Total\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Add each product
      for (final product in widget.bill.products) {
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
      final totalItems = BillingCalculations.calculateTotalItems(
        widget.bill.products,
      );
      final grandTotal = BillingCalculations.calculateGrandTotal(
        widget.bill.products,
      );

      // Total items
      bytes.addAll('Total Items: $totalItems\n'.codeUnits);

      // Subtotal if discount exists
      if (widget.bill.discount > 0) {
        bytes.addAll(
          'Subtotal: Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
        );
        bytes.addAll(
          'Discount: - Rs.${formatCashAmount(widget.bill.discount)}\n'
              .codeUnits,
        );
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Grand total - large and bold
      final netAmount = grandTotal - widget.bill.discount;
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

      if (mounted) {
        if (result) {
          CustomSnackBar.show(
            context,
            message: 'Bill printed successfully',
            type: SnackBarType.success,
          );
          Navigator.pop(context);
        } else {
          CustomSnackBar.show(
            context,
            message: 'Failed to print bill',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing bill: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error printing bill: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = BillingCalculations.calculateTotalItems(
      widget.bill.products,
    );
    final grandTotal = BillingCalculations.calculateGrandTotal(
      widget.bill.products,
    );

    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: _buildDialogHeader(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer and Date Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUSTOMER',
                                style: AppTextStyles.helperText.copyWith(
                                  color: AppColors.gray500,
                                  letterSpacing: 0.5,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                toTitleCase(widget.bill.customerName),
                                style: AppTextStyles.pageTitleBlack.copyWith(
                                  fontSize: 20,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'DATE',
                              style: AppTextStyles.helperText.copyWith(
                                color: AppColors.gray500,
                                letterSpacing: 0.5,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDateShort(widget.bill.date),
                              style: AppTextStyles.inputText.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Items List (Fixed Height with Scrolling)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: widget.bill.products.length,
                            itemBuilder: (context, index) {
                              final product = widget.bill.products[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildBillItem(
                                  '${product.quantity}x',
                                  product.name,
                                  '@${formatCashAmount(product.price)}',
                                  'Rs. ${formatCashAmount(product.price * product.quantity)}',
                                ),
                              );
                            },
                          ),
                          if (_isScrollable) _buildScrollIndicator(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Divider
                    const Divider(color: AppColors.gray300, thickness: 1),
                    const SizedBox(height: 16),

                    // Total Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Items',
                          style: AppTextStyles.inputText.copyWith(
                            color: AppColors.gray500,
                          ),
                        ),
                        Text(
                          '$totalItems',
                          style: AppTextStyles.productItemTotal.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Grand Total (or Subtotal if discount exists)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.bill.discount > 0 ? 'Subtotal' : 'Grand Total',
                          style: AppTextStyles.inputText.copyWith(
                            color: AppColors.gray500,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isPaid && widget.bill.discount == 0) ...[
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Colors.green[600],
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              'Rs. ${formatCashAmount(grandTotal)}',
                              style: AppTextStyles.productItemTotal.copyWith(
                                fontSize: widget.bill.discount > 0 ? 16 : 22,
                                color: widget.bill.discount > 0
                                    ? Colors.black87
                                    : (_isPaid
                                          ? Colors.green[700]
                                          : widget.accentColor),
                                fontWeight: widget.bill.discount > 0
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Show discount section if discount > 0
                    if (widget.bill.discount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount',
                            style: AppTextStyles.inputText.copyWith(
                              color: AppColors.gray500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '- Rs. ${formatCashAmount(widget.bill.discount)}',
                            style: AppTextStyles.productItemTotal.copyWith(
                              fontSize: 16,
                              color: AppColors.pepsiRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.gray300, thickness: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Net Amount',
                            style: AppTextStyles.productItemTotal.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          if (_isPaid) ...[
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'Rs. ${formatCashAmount(grandTotal - widget.bill.discount)}',
                            style: _isPaid
                                ? AppTextStyles.productItemTotal.copyWith(
                                    color: Colors.green[600],
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  )
                                : AppTextStyles.billingTotal.copyWith(
                                    fontSize: 22,
                                    color: widget.accentColor,
                                  ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Reprint Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _printBill,
                        icon: _isPrinting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pepsiWhite,
                                ),
                              )
                            : const Icon(Icons.print, size: 22),
                        label: Text(
                          _isPrinting ? 'Printing...' : 'Reprint Bill',
                          style: AppTextStyles.smallButton.copyWith(
                            color: AppColors.pepsiWhite,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: AppColors.pepsiWhite,
                          disabledBackgroundColor: widget.accentColor
                              .withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Details',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              truncateBillId(widget.bill.billId),
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.pepsiWhite,
            shape: BoxShape.circle,
            border: Border.all(color: widget.accentColor, width: 1.5),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: widget.accentColor, size: 24),
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Widget _buildBillItem(
    String quantity,
    String name,
    String price,
    String total,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              quantity,
              style: AppTextStyles.productItemQuantity.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.productItemName),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: AppTextStyles.helperText.copyWith(
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          Text(total, style: AppTextStyles.productItemTotal),
        ],
      ),
    );
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: widget.accentColor.withValues(alpha: 0.9),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
