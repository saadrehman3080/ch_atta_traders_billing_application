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
      appBar: _buildAppBar(),
      body: billHistory.isEmpty
          ? _buildEmptyState()
          : _buildBillList(billHistory),
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('Sales History', style: AppTextStyles.pageTitleBlack),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.gray300, height: 1),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEmptyStateIcon(),
            const SizedBox(height: 24),
            _buildEmptyStateTitle(),
            const SizedBox(height: 8),
            _buildEmptyStateSubtitle(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList(List<BillHistory> billHistory) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: billHistory.length,
      itemBuilder: (context, index) {
        final bill = billHistory[index];
        return _buildSalesCard(context, bill);
      },
    );
  }

  // ========== Empty State Building Methods ==========

  Widget _buildEmptyStateIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        size: 48,
        color: AppColors.pepsiBlueLight,
      ),
    );
  }

  Widget _buildEmptyStateTitle() {
    return Text(
      'No Sales Records',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
    );
  }

  Widget _buildEmptyStateSubtitle() {
    return Text(
      'Sales transactions will appear here',
      style: AppTextStyles.helperText.copyWith(
        color: AppColors.gray500,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ========== Card Building Methods ==========

  Widget _buildSalesCard(BuildContext context, BillHistory bill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _showBillDetails(context, bill),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _buildCardContent(bill),
        ),
      ),
    );
  }

  Widget _buildCardContent(BillHistory bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTopRow(bill.customerName, grandTotal),
        const SizedBox(height: 6),
        _buildCardBottomRow(bill.formattedDate, bill.formattedTime, totalItems),
      ],
    );
  }

  Widget _buildCardTopRow(String customerName, int grandTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildCustomerName(customerName)),
        const SizedBox(width: 8),
        _buildAmountText(grandTotal),
      ],
    );
  }

  Widget _buildCardBottomRow(String date, String time, int totalItems) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildDateTimeInfo(date, time),
        _buildItemCountBadge(totalItems),
      ],
    );
  }

  Widget _buildCustomerName(String name) {
    return Text(
      name,
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAmountText(int amount) {
    return Text(
      'Rs. ${formatNumber(amount)}',
      style: AppTextStyles.productItemTotal.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.pepsiBlueLight,
      ),
    );
  }

  Widget _buildDateTimeInfo(String date, String time) {
    return Text(
      '$date • $time',
      style: AppTextStyles.helperText.copyWith(
        fontSize: 12,
        color: AppColors.gray500,
      ),
    );
  }

  Widget _buildItemCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count items',
        style: AppTextStyles.helperText.copyWith(
          fontSize: 11,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  // ========== Dialog Methods ==========

  void _showBillDetails(BuildContext context, BillHistory bill) {
    showDialog(
      context: context,
      builder: (context) =>
          BillDetailsDialog(bill: bill, accentColor: AppColors.pepsiBlueLight),
    );
  }
}
