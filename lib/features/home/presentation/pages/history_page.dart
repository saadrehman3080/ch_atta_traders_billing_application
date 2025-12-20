import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_history.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final billHistory = BillHistory.getDummyBillHistory();

    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        backgroundColor: AppColors.pepsiWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Sales History', style: AppTextStyles.pageTitleBlack),
      ),
      body: billHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text(
                    'No sales history yet',
                    style: AppTextStyles.pageSubtitle.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: billHistory.length,
              itemBuilder: (context, index) {
                final bill = billHistory[index];
                return _buildSalesCard(context, bill);
              },
            ),
    );
  }

  Widget _buildSalesCard(BuildContext context, BillHistory bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);

    return InkWell(
      onTap: () => _showBillDetails(context, bill),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pepsiWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.pepsiBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.pepsiBlueLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.customerName, style: AppTextStyles.productItemName),
                  const SizedBox(height: 4),
                  Text(
                    '${bill.formattedDate} • ${bill.formattedTime}',
                    style: AppTextStyles.helperText.copyWith(
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${formatNumber(grandTotal)}',
                  style: AppTextStyles.productItemTotal.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalItems Items',
                  style: AppTextStyles.helperText.copyWith(
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.pepsiBlue, size: 24),
          ],
        ),
      ),
    );
  }

  void _showBillDetails(BuildContext context, BillHistory bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.pepsiWhite,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: _buildDialogHeader(context, bill),
              ),
              //const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    //constraints: const BoxConstraints(maxWidth: 500),
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
                                    style: AppTextStyles.pageTitleBlack
                                        .copyWith(fontSize: 20),
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

                        // Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total',
                              style: AppTextStyles.productItemTotal.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Rs. ${formatNumber(grandTotal)}',
                              style: AppTextStyles.billingTotal.copyWith(
                                fontSize: 22,
                                color: AppColors.pepsiBlue,
                              ),
                            ),
                          ],
                        ),
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
                              backgroundColor: AppColors.pepsiBlue,
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
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context, BillHistory bill) {
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
          decoration: BoxDecoration(
            color: AppColors.pepsiWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pepsiRedLight, width: 1.5),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close,
              color: AppColors.pepsiRedLight,
              size: 28,
            ),
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(),
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
              color: AppColors.pepsiBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              quantity,
              style: AppTextStyles.productItemQuantity.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.pepsiBlue,
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
