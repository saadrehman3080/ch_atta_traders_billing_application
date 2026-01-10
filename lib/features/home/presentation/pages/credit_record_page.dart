import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Displays a list of credit transaction records with delete functionality.
class CreditRecordPage extends StatefulWidget {
  const CreditRecordPage({super.key});

  @override
  State<CreditRecordPage> createState() => _CreditRecordPageState();
}

class _CreditRecordPageState extends State<CreditRecordPage> {
  late final CreditHistoryProvider _creditProvider;
  bool _hasLoadedOnce = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cratesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _creditProvider = CreditHistoryProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load credits every time the page comes into view
    if (!_hasLoadedOnce || ModalRoute.of(context)?.isCurrent == true) {
      _hasLoadedOnce = true;
      _loadCredits();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cratesController.dispose();
    _creditProvider.dispose();
    super.dispose();
  }

  Future<void> _loadCredits() async {
    final salesmanName = await AppPreferences.instance.salesmanName;
    if (salesmanName != null && salesmanName.isNotEmpty) {
      await _creditProvider.loadAllCreditHistory(salesmanName);
    }
  }

  Future<void> _refreshCredits() async {
    final salesmanName = await AppPreferences.instance.salesmanName;
    if (salesmanName != null && salesmanName.isNotEmpty) {
      await _creditProvider.refreshCreditHistory(salesmanName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _creditProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: Consumer<CreditHistoryProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.credits.isEmpty) {
              return _buildLoadingState();
            }

            if (provider.hasError) {
              return _buildErrorState(provider.errorMessage);
            }

            if (provider.credits.isEmpty && !provider.isLoading) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refreshCredits,
              color: AppColors.pepsiBlue,
              child: _buildBillList(provider.credits),
            );
          },
        ),
      ),
    );
  }

  // ========== Business Logic Methods ==========

  void _deleteItem(int index, List<CreditHistory> billHistory) {
    if (!_isValidIndex(index, billHistory)) return;

    final deletedBill = billHistory[index];
    // TODO: Implement Firebase delete functionality
    _showDeleteSnackBar(deletedBill.customerName);
  }

  bool _isValidIndex(int index, List<CreditHistory> billHistory) {
    return index >= 0 && index < billHistory.length;
  }

  void _showDeleteConfirmation(int index, List<CreditHistory> billHistory) {
    final bill = billHistory[index];
    showDialog(
      context: context,
      builder: (context) =>
          _buildDeleteConfirmationDialog(bill, index, billHistory),
    );
  }

  void _showEditDialog(int index, List<CreditHistory> billHistory) {
    final bill = billHistory[index];
    _amountController.clear();
    _cratesController.clear();
    showDialog(
      context: context,
      builder: (context) => _buildEditDialog(bill, index, billHistory),
    );
  }

  Future<void> _updateBillRecord(
    int index,
    int? amountReceived,
    int? cratesReceived,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    final bill = billHistory[index];
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);

    // Calculate new amount due
    int? newAmountDue;
    bool? isPaid;
    if (amountReceived != null && amountReceived > 0) {
      final calculatedAmount = (bill.amountDue - amountReceived).clamp(
        0,
        bill.amountDue,
      );
      if (calculatedAmount == 0) {
        // When fully paid, set amountDue to grandTotal and mark as paid
        newAmountDue = grandTotal;
        isPaid = true;
      } else {
        newAmountDue = calculatedAmount;
      }
    }

    // Calculate new crates due
    int? newCratesDue;
    if (cratesReceived != null && cratesReceived > 0) {
      final calculatedCrates = (bill.cratesDue - cratesReceived).clamp(
        0,
        bill.cratesDue,
      );
      newCratesDue = calculatedCrates;
    }

    // Get salesman name from shared preferences
    final salesmanName = await AppPreferences.instance.salesmanName;
    if (salesmanName == null || salesmanName.isEmpty) {
      _showErrorSnackBar('Unable to get salesman information');
      return;
    }

    // Update in Firebase using provider
    final success = await _creditProvider.updateCreditBalance(
      salesmanName: salesmanName,
      credit: bill,
      newAmountDue: newAmountDue,
      newCratesDue: newCratesDue,
      isPaid: isPaid,
    );

    if (success) {
      _showUpdateSnackBar();
    } else {
      _showErrorSnackBar('Failed to update record');
    }
  }

  void _showUpdateSnackBar() {
    CustomSnackBar.show(
      context,
      message: 'Record updated successfully',
      type: SnackBarType.success,
    );
  }

  void _showErrorSnackBar(String message) {
    CustomSnackBar.show(context, message: message, type: SnackBarType.error);
  }

  void _showDeleteSnackBar(String customerName) {
    CustomSnackBar.show(
      context,
      message: 'Deleted $customerName',
      type: SnackBarType.info,
    );
  }

  void _showBillDetails(CreditHistory bill) {
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.pepsiBlue),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.pepsiRedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Credits',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Something went wrong',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCredits,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiBlue,
                foregroundColor: AppColors.pepsiWhite,
              ),
            ),
          ],
        ),
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
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiBlueLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.pepsiBlueLight,
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

  Widget _buildBillList(List<CreditHistory> billHistory) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: billHistory.length,
      itemBuilder: (context, index) {
        final bill = billHistory[index];
        return _buildCreditCard(bill, index, billHistory);
      },
    );
  }

  // ========== Card Building Methods ==========

  Widget _buildCreditCard(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showBillDetails(bill),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              _buildActionButtons(index, billHistory),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(CreditHistory bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final formattedDate = DateFormat('d-MMM').format(bill.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomerName(bill.customerName),
        const SizedBox(height: 6),
        _buildDateTimeInfo(formattedDate, bill.formattedTime),
        const SizedBox(height: 8),
        _buildAmountSection(
          bill.amountDue,
          totalItems,
          bill.cratesDue,
          bill.isPaid,
        ),
      ],
    );
  }

  Widget _buildCustomerName(String name) {
    return Text(
      toTitleCase(name),
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDateTimeInfo(String date, String time) {
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.gray500),
        const SizedBox(width: 4),
        Text(
          '$date • $time',
          style: AppTextStyles.helperText.copyWith(
            fontSize: 12,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(
    int amountDue,
    int itemCount,
    int cratesDue,
    bool isPaid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAmountText(amountDue, isPaid),
            const SizedBox(width: 8),
            _buildItemCountBadge(itemCount),
          ],
        ),
        if (cratesDue > 0) ...[
          const SizedBox(height: 6),
          _buildPendingCratesText(cratesDue),
        ],
      ],
    );
  }

  Widget _buildAmountText(int amount, bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? Colors.green[50]
            : AppColors.pepsiRedLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaid) ...[
            Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
            const SizedBox(width: 6),
          ],
          Text(
            isPaid && amount == 0 ? 'Paid' : 'Rs. ${formatCashAmount(amount)}',
            style: AppTextStyles.productItemTotal.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: isPaid ? Colors.green[700] : AppColors.pepsiRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCratesText(int cratesDue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange[300]!, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 6),
          Text(
            'Pending: $cratesDue crates',
            style: AppTextStyles.productItemTotal.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gray300, width: 0.5),
      ),
      child: Text(
        '$count items',
        style: AppTextStyles.helperText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(int index, List<CreditHistory> billHistory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showEditDialog(index, billHistory),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pepsiBlueLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: AppColors.pepsiBlueLight,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDeleteConfirmation(index, billHistory),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline,
                color: AppColors.pepsiRedLight,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== Dialog Building Methods ==========

  Dialog _buildDeleteConfirmationDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
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
            _buildDeleteDialogActions(index, billHistory),
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

  Widget _buildDeleteDialogActions(int index, List<CreditHistory> billHistory) {
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
                _deleteItem(index, billHistory);
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

  // ========== Edit Dialog Methods ==========

  Widget _buildEditDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    final totalCrates = BillingCalculations.calculateTotalCrates(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    final hasPendingAmount = bill.amountDue > 0 && !bill.isPaid;
    final hasPendingCrates = bill.cratesDue > 0;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        int? enteredAmount = int.tryParse(_amountController.text);
        int? enteredCrates = int.tryParse(_cratesController.text);

        // Check if user has entered values
        final hasEnteredAmount = enteredAmount != null && enteredAmount > 0;
        final hasEnteredCrates = enteredCrates != null && enteredCrates > 0;

        // Cap entered amount to amountDue
        int displayRemainingAmount = bill.amountDue;
        if (hasEnteredAmount) {
          int cappedAmount = enteredAmount > bill.amountDue
              ? bill.amountDue
              : enteredAmount;
          displayRemainingAmount = bill.amountDue - cappedAmount;
        }

        // Cap entered crates to cratesDue
        int displayRemainingCrates = bill.cratesDue;
        if (hasEnteredCrates) {
          int cappedCrates = enteredCrates > bill.cratesDue
              ? bill.cratesDue
              : enteredCrates;
          displayRemainingCrates = bill.cratesDue - cappedCrates;
        }

        return Dialog(
          backgroundColor: AppColors.pepsiWhite,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEditIcon(),
                  const SizedBox(height: 20),
                  _buildEditTitle(),
                  const SizedBox(height: 8),
                  _buildCustomerNameText(bill.customerName),
                  const SizedBox(height: 24),
                  if (hasPendingAmount)
                    ..._buildEditAmountSection(
                      setDialogState,
                      grandTotal,
                      bill.amountDue,
                      displayRemainingAmount,
                      hasEnteredAmount,
                    ),
                  if (hasPendingAmount && hasPendingCrates) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.gray300),
                    const SizedBox(height: 16),
                  ],
                  if (hasPendingCrates)
                    ..._buildEditCratesSection(
                      setDialogState,
                      totalCrates,
                      bill.cratesDue,
                      displayRemainingCrates,
                      hasEnteredCrates,
                    ),
                  if (!hasPendingAmount && !hasPendingCrates)
                    _buildNothingToEdit(),
                  const SizedBox(height: 24),
                  _buildEditDialogActions(
                    index,
                    hasPendingAmount || hasPendingCrates,
                    billHistory,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditIcon() {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.edit_outlined,
        color: AppColors.pepsiBlueLight,
        size: 32,
      ),
    );
  }

  Widget _buildEditTitle() {
    return Text(
      'Update Record',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCustomerNameText(String customerName) {
    return Text(
      customerName,
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 16,
        color: AppColors.gray500,
      ),
      textAlign: TextAlign.center,
    );
  }

  List<Widget> _buildEditAmountSection(
    StateSetter setDialogState,
    int grandTotal,
    int amountDue,
    int displayRemainingAmount,
    bool hasEnteredAmount,
  ) {
    final showAmountDue = grandTotal != amountDue;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300, width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Bill Total:',
                  style: AppTextStyles.helperText.copyWith(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${formatCashAmount(grandTotal)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (showAmountDue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Amount Due:',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs. ${formatCashAmount(amountDue)}',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _amountController,
          style: AppTextStyles.inputText.copyWith(
            color: Colors.black87,
            fontSize: 14,
          ),
          cursorColor: AppColors.pepsiBlueLight,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'Amount Received',
            labelStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            hintText: 'Enter amount',
            hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            prefixText: 'Rs. ',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.pepsiBlueLight,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            final amount = int.tryParse(value);
            if (amount != null && amount > amountDue) {
              _amountController.text = '0';
              _amountController.selection = TextSelection.fromPosition(
                TextPosition(offset: _amountController.text.length),
              );
            }
            setDialogState(() {});
          },
        ),
      ),
      if (hasEnteredAmount) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: displayRemainingAmount == 0
                ? Colors.green[50]
                : AppColors.pepsiBlueLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: displayRemainingAmount == 0
                  ? Colors.green[300]!
                  : AppColors.pepsiBlueLight.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                displayRemainingAmount == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: displayRemainingAmount == 0
                    ? Colors.green[600]
                    : AppColors.pepsiBlueLight,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                displayRemainingAmount == 0 ? 'Fully Paid' : 'Balance:',
                style: AppTextStyles.helperText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: displayRemainingAmount == 0
                      ? Colors.green[700]
                      : AppColors.pepsiBlue,
                ),
              ),
              if (displayRemainingAmount > 0) ...[
                const Spacer(),
                Text(
                  'Rs. ${formatCashAmount(displayRemainingAmount)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pepsiBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildEditCratesSection(
    StateSetter setDialogState,
    int totalCrates,
    int cratesDue,
    int displayRemainingCrates,
    bool hasEnteredCrates,
  ) {
    final showCratesDue = totalCrates != cratesDue;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300, width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Total Crates:',
                  style: AppTextStyles.helperText.copyWith(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalCrates',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (showCratesDue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.pepsiBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Due:',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$cratesDue',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _cratesController,
          style: AppTextStyles.inputText.copyWith(
            color: Colors.black87,
            fontSize: 14,
          ),
          cursorColor: AppColors.pepsiBlueLight,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'Crates Received',
            labelStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            hintText: 'Enter crates count',
            hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.pepsiBlueLight,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            final crates = int.tryParse(value);
            if (crates != null && crates > cratesDue) {
              _cratesController.text = '0';
              _cratesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _cratesController.text.length),
              );
            }
            setDialogState(() {});
          },
        ),
      ),
      if (hasEnteredCrates) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: displayRemainingCrates == 0
                ? Colors.green[50]
                : AppColors.pepsiBlueLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: displayRemainingCrates == 0
                  ? Colors.green[300]!
                  : AppColors.pepsiBlueLight.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                displayRemainingCrates == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: displayRemainingCrates == 0
                    ? Colors.green[600]
                    : AppColors.pepsiBlueLight,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                displayRemainingCrates == 0 ? 'All Returned' : 'Balance:',
                style: AppTextStyles.helperText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: displayRemainingCrates == 0
                      ? Colors.green[700]
                      : AppColors.pepsiBlue,
                ),
              ),
              if (displayRemainingCrates > 0) ...[
                const Spacer(),
                Text(
                  '$displayRemainingCrates',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pepsiBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildNothingToEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All payments received and crates returned',
              style: AppTextStyles.helperText.copyWith(
                fontSize: 14,
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditDialogActions(
    int index,
    bool hasEditableFields,
    List<CreditHistory> billHistory,
  ) {
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
              onPressed: hasEditableFields
                  ? () {
                      final amountReceived = int.tryParse(
                        _amountController.text,
                      );
                      final cratesReceived = int.tryParse(
                        _cratesController.text,
                      );

                      if ((amountReceived != null && amountReceived > 0) ||
                          (cratesReceived != null && cratesReceived > 0)) {
                        Navigator.pop(context);
                        _updateBillRecord(
                          index,
                          amountReceived,
                          cratesReceived,
                          billHistory,
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiBlueLight,
                foregroundColor: AppColors.pepsiWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Update',
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
