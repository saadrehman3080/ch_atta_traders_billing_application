import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/cleared_bill.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/customer_bulk_payment.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/cleared_bill_repository.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/customer_bulk_payment_repository.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/dashboard_repository.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_history_provider.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/sale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Page for recording bulk payments against a customer that has two or more
/// pending credit bills.  Payment is tracked at the customer level (grand
/// total of all bills) rather than against each individual bill.  Individual
/// bills are only marked as paid once the full outstanding amount is collected.
class CustomerBulkPaymentPage extends StatefulWidget {
  final List<CreditHistory> bills;
  final String salesmanName;
  final CreditHistoryProvider creditProvider;

  const CustomerBulkPaymentPage({
    super.key,
    required this.bills,
    required this.salesmanName,
    required this.creditProvider,
  });

  @override
  State<CustomerBulkPaymentPage> createState() =>
      _CustomerBulkPaymentPageState();
}

class _CustomerBulkPaymentPageState extends State<CustomerBulkPaymentPage>
    with TickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _cratesReturnController = TextEditingController();
  final _bulkRepo = CustomerBulkPaymentRepository();

  List<CreditHistory>? _localBills;
  List<CreditHistory> get _bills => _localBills ?? widget.bills;
  CustomerBulkPayment? _bulkPayment;
  bool _isLoading = true;
  bool _isSubmittingPayment = false;
  bool _isSubmittingCrates = false;
  bool _isCompletingBills = false;

  // ── derived values ────────────────────────────────────────────────────────

  String get _customerName => _bills.first.customerName;

  /// Bills sorted by amountDue ascending so smaller bills are covered first.
  List<CreditHistory> get _sortedBills =>
      List<CreditHistory>.from(_bills)
        ..sort((a, b) => a.amountDue.compareTo(b.amountDue));

  /// Sum of amountDue across all bills for this customer.
  int get _totalAmountDue => _bills.fold(0, (sum, b) => sum + b.amountDue);

  /// Amount already collected (stored in the bulk payment record).
  int get _totalPaid => _bulkPayment?.totalPaid ?? 0;

  /// Outstanding balance after accounting for already-collected payments.
  int get _remaining =>
      (_totalAmountDue - _totalPaid).clamp(0, _totalAmountDue);

  /// Total empty crates due across all bills.
  int get _totalCratesDue => _bills.fold(0, (sum, b) => sum + b.cratesDue);

  /// Whether any bill has pending empty crates.
  bool get _hasPendingCrates => _totalCratesDue > 0;

  bool get _isFullyPaid =>
      _remaining == 0 && _totalAmountDue > 0 && _totalCratesDue == 0;

  /// Splits bills into completed (fully covered by accumulated payment AND
  /// crates returned) and pending.  Bills are sorted by amountDue ascending so
  /// smaller bills are covered first.  A bill is only completed when both its
  /// cash is fully paid AND its crates are fully returned.
  ({List<CreditHistory> completed, List<CreditHistory> pending})
  get _billSplit {
    final completed = <CreditHistory>[];
    final pending = <CreditHistory>[];
    final sorted = _sortedBills;
    int budget = _totalPaid;
    for (int i = 0; i < sorted.length; i++) {
      final bill = sorted[i];
      final cashCovered = budget >= bill.amountDue && bill.amountDue > 0;
      final cratesCovered = bill.cratesDue == 0;
      if (cashCovered && cratesCovered) {
        budget -= bill.amountDue;
        completed.add(bill);
      } else if (cashCovered && !cratesCovered) {
        // Cash is paid but crates still pending — keep in pending
        budget -= bill.amountDue;
        pending.add(bill);
      } else {
        // This bill can't be covered — add it and all remaining to pending
        pending.addAll(sorted.sublist(i));
        break;
      }
    }
    return (completed: completed, pending: pending);
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _localBills = List<CreditHistory>.from(widget.bills);
    _loadBulkPayment();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cratesReturnController.dispose();
    super.dispose();
  }

  // ── data methods ──────────────────────────────────────────────────────────

  Future<void> _loadBulkPayment() async {
    setState(() => _isLoading = true);
    final payment = await _bulkRepo.getBulkPayment(
      salesmanName: widget.salesmanName,
      customerName: _customerName,
    );
    if (mounted) {
      setState(() {
        _bulkPayment = payment;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter an amount.');
      return;
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid positive amount.');
      return;
    }

    // Cap at remaining
    final cappedAmount = amount > _remaining ? _remaining : amount;

    setState(() => _isSubmittingPayment = true);

    // On first payment, capture each bill's amountDue as a snapshot
    final isFirstPayment = _bulkPayment == null;
    Map<String, int>? billAmountsSnapshot;
    if (isFirstPayment) {
      billAmountsSnapshot = {for (final b in _bills) b.billId: b.amountDue};
    }

    final success = await _bulkRepo.addPaymentEntry(
      salesmanName: widget.salesmanName,
      customerName: _customerName,
      amount: cappedAmount,
      date: DateTime.now(),
      billAmounts: billAmountsSnapshot,
    );

    if (!success) {
      if (mounted) {
        _showError('Failed to record payment. Please try again.');
        setState(() => _isSubmittingPayment = false);
      }
      return;
    }

    // Reload updated record from Firebase
    final updatedPayment = await _bulkRepo.getBulkPayment(
      salesmanName: widget.salesmanName,
      customerName: _customerName,
    );

    final newTotalPaid = updatedPayment?.totalPaid ?? 0;
    final newRemaining = (_totalAmountDue - newTotalPaid).clamp(
      0,
      _totalAmountDue,
    );

    if (mounted) {
      setState(() {
        _bulkPayment = updatedPayment;
        _isSubmittingPayment = false;
      });
    }

    _amountController.clear();

    if (newRemaining == 0 && _totalAmountDue > 0 && _totalCratesDue == 0) {
      // All cash paid AND all crates returned — complete everything
      if (mounted) {
        setState(() => _isCompletingBills = true);
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await _markAllBillsPaid();
    } else {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Payment of Rs. ${formatCashAmount(cappedAmount)} recorded.',
          type: SnackBarType.success,
        );
      }
    }
  }

  /// Records returned empty crates, distributing them across bills that have
  /// pending crates (smallest cratesDue first).  Updates each bill in Firebase
  /// and the dashboard.  If all cash AND crates are then settled, triggers
  /// the full-completion flow.
  Future<void> _submitCrateReturn() async {
    final text = _cratesReturnController.text.trim();
    if (text.isEmpty) {
      _showError('Please enter the number of crates returned.');
      return;
    }
    final cratesReturned = int.tryParse(text);
    if (cratesReturned == null || cratesReturned <= 0) {
      _showError('Please enter a valid number.');
      return;
    }

    final capped = cratesReturned > _totalCratesDue
        ? _totalCratesDue
        : cratesReturned;

    setState(() => _isSubmittingCrates = true);

    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      if (mounted) {
        setState(() => _isSubmittingCrates = false);
        _showError('Salesman identifier not found. Please log in again.');
      }
      return;
    }

    final dashboardRepo = DashboardRepository();
    final today = DateTime.now();

    // Sort bills by cratesDue ascending so smaller ones get cleared first
    final billsWithCrates = List<CreditHistory>.from(
      _bills.where((b) => b.cratesDue > 0),
    )..sort((a, b) => a.cratesDue.compareTo(b.cratesDue));

    int remaining = capped;
    for (final bill in billsWithCrates) {
      if (remaining <= 0) break;

      final toDeduct = remaining >= bill.cratesDue ? bill.cratesDue : remaining;
      final newCratesDue = bill.cratesDue - toDeduct;
      remaining -= toDeduct;

      // Update this bill's cratesDue in Firebase
      await widget.creditProvider.updateCreditBalance(
        salesmanName: salesmanIdentifier,
        credit: bill,
        newCratesDue: newCratesDue,
        isRecordUpdated: true,
      );

      // Update local bill list to reflect the change
      final localIndex = _bills.indexWhere((b) => b.billId == bill.billId);
      if (localIndex != -1) {
        _bills[localIndex] = _bills[localIndex].copyWith(
          cratesDue: newCratesDue,
        );
      }

      // Update dashboard for crate returns
      final isTodaysBill =
          bill.date.year == today.year &&
          bill.date.month == today.month &&
          bill.date.day == today.day;

      if (isTodaysBill) {
        await dashboardRepo.updateSummaryOnPartialPayment(
          salesmanName: salesmanIdentifier,
          date: bill.date,
          cratesReceived: toDeduct,
          isPaidBill: bill.isPaid,
        );
      } else {
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: salesmanIdentifier,
          cratesReceived: toDeduct,
        );
      }
    }

    if (mounted) {
      setState(() => _isSubmittingCrates = false);
      _cratesReturnController.clear();
      CustomSnackBar.show(
        context,
        message: '$capped empty ${capped == 1 ? 'crate' : 'crates'} recorded.',
        type: SnackBarType.success,
      );
    }

    // Check if everything is now cleared
    if (_remaining == 0 && _totalAmountDue > 0 && _totalCratesDue == 0) {
      if (mounted) {
        setState(() => _isCompletingBills = true);
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await _markAllBillsPaid();
    }
  }

  /// Completes all bills for this customer using the same flow as the tick
  /// button on the credit record page: saves each bill to sale history, updates
  /// the dashboard, deletes from credit records, then removes the bulk payment
  /// record and pops the page.
  Future<void> _markAllBillsPaid() async {
    if (!mounted) return;
    setState(() => _isSubmittingPayment = true);

    final saleProvider = SaleProvider();
    final dashboardRepo = DashboardRepository();
    final clearedBillRepo = ClearedBillRepository();
    final today = DateTime.now();

    for (final bill in _bills) {
      // 1. Save to sale history
      final saleHistory = SaleHistory(
        billId: bill.billId,
        customerName: bill.customerName,
        date: bill.date,
        products: bill.products,
        discount: bill.discount,
        billType: BillType.credit,
      );
      final savedAsSale = await saleProvider.saveSaleFromCreditConversion(
        saleHistory,
        widget.salesmanName,
      );
      if (!savedAsSale) continue; // best-effort for each bill

      // 2. Update dashboard
      final isTodaysBill =
          bill.date.year == today.year &&
          bill.date.month == today.month &&
          bill.date.day == today.day;

      if (isTodaysBill) {
        await dashboardRepo.updateSummaryOnCreditToSale(
          salesmanName: widget.salesmanName,
          date: bill.date,
          amountDue: bill.amountDue,
          cratesDue: bill.cratesDue,
          isPaidBill: bill.isPaid,
        );
      } else {
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: widget.salesmanName,
          cashReceived: bill.isPaid ? null : bill.amountDue,
          cratesReceived: bill.cratesDue,
        );
        // Save cleared-bill record for previous-day collection view
        try {
          final clearedBill = ClearedBill.fromCreditHistory(
            credit: bill,
            amountPaidToday: bill.isPaid ? 0 : bill.amountDue,
            cratesReturnedToday: bill.cratesDue,
          );
          await clearedBillRepo.deletePartialEntries(
            salesmanName: widget.salesmanName,
            billId: bill.billId,
          );
          await clearedBillRepo.saveClearedBill(
            salesmanName: widget.salesmanName,
            clearedBill: clearedBill,
          );
        } catch (e) {
          debugPrint('Error saving cleared bill: $e');
        }
      }

      // 3. Delete from credit history
      await widget.creditProvider.deleteCreditRecord(
        billId: bill.billId,
        salesmanName: widget.salesmanName,
      );
    }

    // 4. Remove bulk payment record
    await _bulkRepo.deleteBulkPayment(
      salesmanName: widget.salesmanName,
      customerName: _customerName,
    );

    if (mounted) {
      setState(() => _isSubmittingPayment = false);
      CustomSnackBar.show(
        context,
        message: 'All bills marked as paid and moved to sales!',
        type: SnackBarType.success,
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _showError(String message) {
    CustomSnackBar.show(context, message: message, type: SnackBarType.error);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pepsiBlue),
            )
          : _isCompletingBills
          ? _buildCompletionAnimation()
          : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit Payment',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            toTitleCase(_customerName),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.gray300.withValues(alpha: 0.5),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final history = _bulkPayment?.paymentHistory ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 14),
          if (!_isFullyPaid) ...[
            if (_remaining > 0) ...[
              _buildPaymentInputSection(),
              const SizedBox(height: 14),
            ],
            if (_hasPendingCrates) ...[
              _buildCrateReturnSection(),
              const SizedBox(height: 14),
            ],
          ],
          if (history.isNotEmpty) _buildPaymentHistorySection(history),
          const SizedBox(height: 14),
          _buildBillsSection(),
        ],
      ),
    );
  }

  Widget _buildCompletionAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Marking all bills as paid...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Moving ${_bills.length} ${_bills.length == 1 ? 'bill' : 'bills'} to sales history',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final progress = _totalAmountDue > 0
        ? (_totalPaid / _totalAmountDue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.pepsiRed,
            AppColors.pepsiRedLight.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.pepsiRed.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badge row
          Row(
            children: [
              _badge(
                '${_bills.length} ${_bills.length == 1 ? 'Bill' : 'Bills'}',
              ),
              if (_remaining == 0 && _hasPendingCrates) ...[
                const SizedBox(width: 8),
                _badge('Cash Cleared', green: true),
              ] else if (_totalPaid > 0 && !_isFullyPaid) ...[
                const SizedBox(width: 8),
                _badge('Partial Payment', orange: true),
              ],
              if (_isFullyPaid) ...[
                const SizedBox(width: 8),
                _badge('✓  Fully Settled', green: true),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  'Total Due',
                  'Rs. ${formatCashAmount(_totalAmountDue)}',
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Total Paid',
                  'Rs. ${formatCashAmount(_totalPaid)}',
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Remaining',
                  'Rs. ${formatCashAmount(_remaining)}',
                  highlight: _remaining == 0 && _totalAmountDue > 0,
                ),
              ),
            ],
          ),
          // Crates row (only shown when any bill has pending crates)
          if (_hasPendingCrates) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Empty Crates Pending:',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_totalCratesDue',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          // Progress bar
          if (_totalAmountDue > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isFullyPaid
                            ? Colors.greenAccent
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, {bool green = false, bool orange = false}) {
    Color bg;
    if (green) {
      bg = Colors.green.withValues(alpha: 0.35);
    } else if (orange) {
      bg = Colors.orange.withValues(alpha: 0.35);
    } else {
      bg = Colors.white.withValues(alpha: 0.2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: highlight ? Colors.greenAccent : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Bills list ────────────────────────────────────────────────────────────

  Widget _buildBillsSection() {
    final split = _billSplit;
    return Column(
      children: [
        if (split.completed.isNotEmpty)
          _buildCompletedBillsCard(split.completed),
        if (split.completed.isNotEmpty && split.pending.isNotEmpty)
          const SizedBox(height: 14),
        if (split.pending.isNotEmpty) _buildPendingBillsCard(split.pending),
      ],
    );
  }

  Widget _buildCompletedBillsCard(List<CreditHistory> bills) {
    final completedTotal = bills.fold(0, (sum, b) => sum + b.amountDue);
    return _card(
      borderColor: Colors.green.withValues(alpha: 0.25),
      shadowColor: Colors.green.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 15,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Completed Bills',
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[800],
                  ),
                ),
                if (bills.length > 1) ...[
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Paid Total',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                      Text(
                        'Rs. ${formatCashAmount(completedTotal)}',
                        style: AppTextStyles.productItemTotal.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _divider(),
          ...bills.asMap().entries.map((e) {
            return _buildCompletedBillRow(
              e.value,
              index: e.key + 1,
              isLast: e.key == bills.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPendingBillsCard(List<CreditHistory> bills) {
    final pendingTotal = bills.fold(0, (sum, b) => sum + b.amountDue);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.pepsiRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 15,
                    color: AppColors.pepsiRed,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Bills',
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (bills.length > 1) ...[
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Remaining',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                      Text(
                        'Rs. ${formatCashAmount(pendingTotal)}',
                        style: AppTextStyles.productItemTotal.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pepsiRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _divider(),
          ...bills.asMap().entries.map((e) {
            return _buildBillRow(
              e.value,
              index: e.key + 1,
              isLast: e.key == bills.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompletedBillRow(
    CreditHistory bill, {
    required int index,
    required bool isLast,
  }) {
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final formattedDate = DateFormat('d MMM yy').format(bill.date);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Bill $index',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 10,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${bill.billId.length > 6 ? bill.billId.substring(0, 6) : bill.billId}',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 10,
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$formattedDate  •  ${bill.formattedTime}',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalItems items',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                    if (bill.discount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Bill: Rs. ${formatCashAmount(grandTotal)}  (−${bill.discount} disc.)',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 15, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Rs. ${formatCashAmount(bill.amountDue)}',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.gray300.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildBillRow(
    CreditHistory bill, {
    required int index,
    required bool isLast,
  }) {
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final formattedDate = DateFormat('d MMM yy').format(bill.date);
    final isPaidFully = bill.isPaid && bill.amountDue == 0;
    final cashPaid = isPaidFully || bill.amountDue == 0;
    final hasCratesPending = bill.cratesDue > 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pepsiBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Bill $index',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 10,
                              color: AppColors.pepsiBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${bill.billId.length > 6 ? bill.billId.substring(0, 6) : bill.billId}',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 10,
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$formattedDate  •  ${bill.formattedTime}',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalItems items',
                          style: AppTextStyles.helperText.copyWith(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                    if (bill.discount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Bill: Rs. ${formatCashAmount(grandTotal)}  (−${bill.discount} disc.)',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 10,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                    if (hasCratesPending) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 11,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${bill.cratesDue} ${bill.cratesDue == 1 ? 'crate' : 'crates'} pending',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: status column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cashPaid)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasCratesPending ? 'Cash Paid' : 'Paid',
                          style: AppTextStyles.productItemTotal.copyWith(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Rs. ${formatCashAmount(bill.amountDue)}',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 14,
                        color: AppColors.pepsiRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.gray300.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  // ── Payment input ─────────────────────────────────────────────────────────

  Widget _buildPaymentInputSection() {
    return _card(
      borderColor: AppColors.pepsiBlue.withValues(alpha: 0.2),
      shadowColor: AppColors.pepsiBlue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final entered = int.tryParse(_amountController.text.trim());
            final hasEntered = entered != null && entered > 0;
            final capped = hasEntered
                ? (entered > _remaining ? _remaining : entered)
                : null;
            final afterPay = capped != null
                ? (_remaining - capped).clamp(0, _remaining)
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.pepsiBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.pepsiBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Record Payment',
                      style: AppTextStyles.productItemName.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Remaining balance row
                Row(
                  children: [
                    Text(
                      'Remaining Balance:',
                      style: AppTextStyles.helperText.copyWith(
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Rs. ${formatCashAmount(_remaining)}',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pepsiRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount text field
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
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final amount = int.tryParse(value);
                      if (amount != null && amount > _remaining) {
                        final capped = _remaining.toString();
                        _amountController.value = TextEditingValue(
                          text: capped,
                          selection: TextSelection.collapsed(
                            offset: capped.length,
                          ),
                        );
                      }
                      setLocal(() {});
                    },
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: AppTextStyles.inputText.copyWith(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    cursorColor: AppColors.pepsiBlue,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.gray50,
                      labelText: 'Amount Received',
                      labelStyle: AppTextStyles.inputHint.copyWith(
                        fontSize: 14,
                        color: AppColors.gray400,
                      ),
                      floatingLabelStyle: AppTextStyles.inputHint.copyWith(
                        fontSize: 14,
                        color: AppColors.pepsiBlue,
                        fontWeight: FontWeight.w500,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      prefixText: 'Rs.  ',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.gray300.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.pepsiBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Remaining after payment preview
                if (afterPay != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: afterPay == 0
                            ? Colors.green[400]!
                            : Colors.green[200]!,
                        width: afterPay == 0 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          afterPay == 0
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: afterPay == 0
                              ? Text(
                                  'All bills will be marked as paid!',
                                  style: AppTextStyles.helperText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                )
                              : RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.helperText.copyWith(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Remaining after payment:  ',
                                      ),
                                      TextSpan(
                                        text:
                                            'Rs. ${formatCashAmount(afterPay)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isSubmittingPayment || _isSubmittingCrates)
                        ? null
                        : _submitPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pepsiBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.pepsiBlue.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmittingPayment
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Record Payment',
                            style: AppTextStyles.smallButton.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Crate return input ─────────────────────────────────────────────────

  Widget _buildCrateReturnSection() {
    return _card(
      borderColor: Colors.orange.withValues(alpha: 0.25),
      shadowColor: Colors.orange.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final entered = int.tryParse(_cratesReturnController.text.trim());
            final hasEntered = entered != null && entered > 0;
            final capped = hasEntered
                ? (entered > _totalCratesDue ? _totalCratesDue : entered)
                : null;
            final afterReturn = capped != null
                ? (_totalCratesDue - capped).clamp(0, _totalCratesDue)
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orange[700],
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Record Empty Crates',
                      style: AppTextStyles.productItemName.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Crates Pending:',
                      style: AppTextStyles.helperText.copyWith(
                        fontSize: 13,
                        color: AppColors.gray500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_totalCratesDue',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: const TextSelectionThemeData(
                      selectionHandleColor: AppColors.pepsiBlueLight,
                      selectionColor: AppColors.textSecondary,
                      cursorColor: AppColors.pepsiBlueLight,
                    ),
                  ),
                  child: TextField(
                    controller: _cratesReturnController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final count = int.tryParse(value);
                      if (count != null && count > _totalCratesDue) {
                        final capped = _totalCratesDue.toString();
                        _cratesReturnController.value = TextEditingValue(
                          text: capped,
                          selection: TextSelection.collapsed(
                            offset: capped.length,
                          ),
                        );
                      }
                      setLocal(() {});
                    },
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: AppTextStyles.inputText.copyWith(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    cursorColor: AppColors.pepsiBlue,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.gray50,
                      labelText: 'Crates Returned',
                      labelStyle: AppTextStyles.inputHint.copyWith(
                        fontSize: 14,
                        color: AppColors.gray400,
                      ),
                      floatingLabelStyle: AppTextStyles.inputHint.copyWith(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: Colors.orange[600],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.gray300.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.orange[600]!,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (afterReturn != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: afterReturn == 0
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: afterReturn == 0
                            ? Colors.green[400]!
                            : Colors.orange[200]!,
                        width: afterReturn == 0 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          afterReturn == 0
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 16,
                          color: afterReturn == 0
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: afterReturn == 0
                              ? Text(
                                  'All crates will be returned!',
                                  style: AppTextStyles.helperText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                )
                              : RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.helperText.copyWith(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Crates still pending:  ',
                                      ),
                                      TextSpan(
                                        text: '$afterReturn',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isSubmittingCrates || _isSubmittingPayment)
                        ? null
                        : _submitCrateReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.orange.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmittingCrates
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Record Crates',
                            style: AppTextStyles.smallButton.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Payment history ───────────────────────────────────────────────────────

  /// Computes which bills were fully covered after each payment entry.
  /// Returns a list of items (one per history entry, oldest→newest) where each
  /// item contains a list of bill IDs that became fully paid at that step.
  /// Uses the same sorted-by-amountDue order as [_billSplit].
  List<List<String>> _computeBillCompletionsPerEntry(
    List<BulkPaymentEntry> chronological,
  ) {
    final sorted = _sortedBills;
    final result = <List<String>>[];
    int runningTotal = 0;
    int coveredSoFar = 0; // index into sorted bills

    for (final entry in chronological) {
      runningTotal += entry.amount;
      final newlyCompleted = <String>[];
      while (coveredSoFar < sorted.length) {
        final bill = sorted[coveredSoFar];
        if (bill.amountDue <= 0) {
          coveredSoFar++;
          continue;
        }
        final needed = sorted
            .take(coveredSoFar + 1)
            .fold(0, (s, b) => s + b.amountDue);
        if (runningTotal >= needed) {
          newlyCompleted.add(bill.billId);
          coveredSoFar++;
        } else {
          break;
        }
      }
      result.add(newlyCompleted);
    }
    return result;
  }

  Widget _buildPaymentHistorySection(List<BulkPaymentEntry> history) {
    // Chronological order for computing completions
    final chronological = List<BulkPaymentEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final completionsPerEntry = _computeBillCompletionsPerEntry(chronological);

    // Display newest first – reverse both lists
    final displayEntries = chronological.reversed.toList();
    final displayCompletions = completionsPerEntry.reversed.toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.pepsiBlue),
                const SizedBox(width: 6),
                Text(
                  'Payment History',
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pepsiBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${displayEntries.length} ${displayEntries.length == 1 ? 'entry' : 'entries'}',
                    style: GoogleFonts.poppins(
                      color: AppColors.pepsiBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _divider(),
          ...displayEntries.asMap().entries.map((e) {
            final completedBillIds = displayCompletions[e.key];
            return _buildHistoryRow(
              e.value,
              completedBillIds: completedBillIds,
              isLast: e.key == displayEntries.length - 1,
            );
          }),
          // Total paid footer – only shown when there are multiple entries
          if (displayEntries.length > 1) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Total Collected',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs. ${formatCashAmount(_totalPaid)}',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryRow(
    BulkPaymentEntry entry, {
    required List<String> completedBillIds,
    required bool isLast,
  }) {
    final formattedDate = DateFormat('d MMM yyyy,  h:mm a').format(entry.date);
    final hasCompletions = completedBillIds.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasCompletions ? Colors.green[100] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCompletions ? Icons.check_circle : Icons.check,
                  size: 16,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Received',
                      style: AppTextStyles.helperText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: AppTextStyles.helperText.copyWith(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                    ),
                    if (hasCompletions) ...[
                      const SizedBox(height: 4),
                      ...completedBillIds.map((billId) {
                        final shortId = billId.length > 6
                            ? billId.substring(0, 6)
                            : billId;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 12,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bill #$shortId fully paid',
                                style: AppTextStyles.helperText.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              Text(
                'Rs. ${formatCashAmount(entry.amount)}',
                style: AppTextStyles.productItemTotal.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 58,
            endIndent: 16,
            color: AppColors.gray300.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _card({
    required Widget child,
    Color? borderColor,
    Color? shadowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? AppColors.gray300.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: AppColors.gray300.withValues(alpha: 0.5));
}
