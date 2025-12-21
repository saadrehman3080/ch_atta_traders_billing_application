import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_history.dart';
import 'package:flutter/material.dart';

class BillDetailsDialog extends StatelessWidget {
  final BillHistory bill;
  final Color accentColor;

  const BillDetailsDialog({
    super.key,
    required this.bill,
    this.accentColor = AppColors.pepsiBlue,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);

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
                                bill.customerName,
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
                              bill.formattedDate,
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
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: bill.products.length,
                        itemBuilder: (context, index) {
                          final product = bill.products[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildBillItem(
                              '${product.quantity}x',
                              product.name,
                              '@${formatNumber(product.price)}',
                              'Rs. ${formatNumber(product.price * product.quantity)}',
                            ),
                          );
                        },
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
                          bill.discount > 0 ? 'Subtotal' : 'Grand Total',
                          style: AppTextStyles.inputText.copyWith(
                            color: AppColors.gray500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Rs. ${formatNumber(grandTotal)}',
                          style: AppTextStyles.productItemTotal.copyWith(
                            fontSize: bill.discount > 0 ? 16 : 22,
                            color: bill.discount > 0
                                ? Colors.black87
                                : accentColor,
                            fontWeight: bill.discount > 0
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Show discount section if discount > 0
                    if (bill.discount > 0) ...[
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
                            '- Rs. ${formatNumber(bill.discount)}',
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net Amount',
                            style: AppTextStyles.productItemTotal.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rs. ${formatNumber(grandTotal - bill.discount)}',
                            style: AppTextStyles.billingTotal.copyWith(
                              fontSize: 22,
                              color: accentColor,
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
                        onPressed: () {
                          Navigator.pop(context);
                          // Add your print logic here
                        },
                        icon: const Icon(Icons.print, size: 22),
                        label: Text(
                          'Reprint Bill',
                          style: AppTextStyles.smallButton.copyWith(
                            color: AppColors.pepsiWhite,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: AppColors.pepsiWhite,
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
              bill.billId,
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
            border: Border.all(color: accentColor, width: 1.5),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: accentColor, size: 24),
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
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              quantity,
              style: AppTextStyles.productItemQuantity.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
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
}
