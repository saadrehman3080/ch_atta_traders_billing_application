import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
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
      onTap: () => showDialog(
        context: context,
        builder: (context) => BillDetailsDialog(bill: bill),
      ),
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
            // const SizedBox(width: 8),
            // Icon(Icons.chevron_right, color: AppColors.pepsiBlue, size: 24),
          ],
        ),
      ),
    );
  }
}
