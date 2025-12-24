import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_history.dart';
import 'package:flutter/material.dart';

/// Displays a list of credit transaction records with delete functionality.
class CreditRecordPage extends StatefulWidget {
  const CreditRecordPage({super.key});

  @override
  State<CreditRecordPage> createState() => _CreditRecordPageState();
}

class _CreditRecordPageState extends State<CreditRecordPage> {
  late List<BillHistory> billHistory;

  @override
  void initState() {
    super.initState();
    _initializeBillHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: _buildAppBar(),
      body: billHistory.isEmpty ? _buildEmptyState() : _buildBillList(),
    );
  }

  // ========== Business Logic Methods ==========

  void _initializeBillHistory() {
    billHistory = BillHistory.getDummyBillHistory();
  }

  void _deleteItem(int index) {
    if (!_isValidIndex(index)) return;

    final deletedBill = billHistory[index];
    setState(() {
      billHistory.removeAt(index);
    });
    _showDeleteSnackBar(deletedBill.customerName);
  }

  bool _isValidIndex(int index) {
    return index >= 0 && index < billHistory.length;
  }

  void _showDeleteConfirmation(int index) {
    final bill = billHistory[index];
    showDialog(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(bill, index),
    );
  }

  void _showDeleteSnackBar(String customerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $customerName'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBillDetails(BillHistory bill) {
    showDialog(
      context: context,
      builder: (context) =>
          BillDetailsDialog(bill: bill, accentColor: AppColors.pepsiRedLight),
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('Credit History', style: AppTextStyles.pageTitleBlack),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_outlined,
                size: 40,
                color: AppColors.pepsiRedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Credit Records',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Credit transactions will appear here',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: billHistory.length,
      itemBuilder: (context, index) {
        final bill = billHistory[index];
        return _buildCreditCard(bill, index);
      },
    );
  }

  // ========== Card Building Methods ==========

  Widget _buildCreditCard(BillHistory bill, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _showBillDetails(bill),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: _buildCardContent(bill)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 60,
                  child: VerticalDivider(
                    color: AppColors.gray300,
                    thickness: 1,
                  ),
                ),
              ),
              _buildDeleteButton(index),
            ],
          ),
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
        _buildCustomerName(bill.customerName),
        const SizedBox(height: 6),
        _buildDateTimeInfo(bill.formattedDate, bill.formattedTime),
        const SizedBox(height: 8),
        _buildAmountSection(
          grandTotal,
          totalItems,
          bill.remainingCrates,
          bill.isPaid,
        ),
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

  Widget _buildDateTimeInfo(String date, String time) {
    return Text(
      '$date • $time',
      style: AppTextStyles.helperText.copyWith(
        fontSize: 12,
        color: AppColors.gray500,
      ),
    );
  }

  Widget _buildAmountSection(
    int amount,
    int itemCount,
    int remainingCrates,
    bool isPaid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAmountText(amount, isPaid),
            const SizedBox(width: 8),
            _buildItemCountBadge(itemCount),
          ],
        ),
        if (remainingCrates > 0) ...[
          const SizedBox(height: 6),
          _buildPendingCratesText(remainingCrates),
        ],
      ],
    );
  }

  Widget _buildAmountText(int amount, bool isPaid) {
    return Row(
      children: [
        if (isPaid) ...[
          Icon(Icons.check_circle_outline, size: 18, color: Colors.green[600]),
          const SizedBox(width: 4),
        ],
        Text(
          'Rs. ${formatNumber(amount)}',
          style: AppTextStyles.productItemTotal.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isPaid ? Colors.green[600] : AppColors.pepsiRedLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCratesText(int remainingCrates) {
    return Text(
      'Pending Crates: $remainingCrates',
      style: AppTextStyles.productItemTotal.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.pepsiRedLight,
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

  Widget _buildDeleteButton(int index) {
    return IconButton(
      onPressed: () => _showDeleteConfirmation(index),
      icon: const Icon(Icons.delete_outline),
      color: AppColors.pepsiRedLight,
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Delete record',
    );
  }

  // ========== Dialog Building Methods ==========

  Dialog _buildDeleteConfirmationDialog(BillHistory bill, int index) {
    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDeleteIcon(),
            const SizedBox(height: 20),
            _buildDeleteTitle(),
            const SizedBox(height: 12),
            _buildDeleteMessage(bill.customerName),
            const SizedBox(height: 24),
            _buildDeleteDialogActions(index),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.pepsiRedLight.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.delete_outline,
        color: AppColors.pepsiRedLight,
        size: 32,
      ),
    );
  }

  Widget _buildDeleteTitle() {
    return Text(
      'Delete Record?',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
    );
  }

  Widget _buildDeleteMessage(String customerName) {
    return Text(
      'Are you sure you want to delete $customerName\'s credit record? This action cannot be undone.',
      textAlign: TextAlign.center,
      style: AppTextStyles.helperText.copyWith(
        color: AppColors.gray500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildDeleteDialogActions(int index) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gray300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: AppTextStyles.smallButton.copyWith(
                  color: AppColors.gray500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteItem(index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiRedLight,
                foregroundColor: AppColors.pepsiWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Delete',
                style: AppTextStyles.smallButton.copyWith(
                  color: AppColors.pepsiWhite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
