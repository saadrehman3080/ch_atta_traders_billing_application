import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/cleared_bill_detail_dialog.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/tap_scale_wrapper.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/cleared_bill.dart';
import 'package:ch_atta_traders_billing_application/features/home/providers/cleared_bills_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Page showing previous-day credit bills that were fully cleared (paid) today.
/// Accessible by tapping the "Previous Day Collection" card on the dashboard.
class ClearedBillsPage extends StatefulWidget {
  const ClearedBillsPage({super.key});

  @override
  State<ClearedBillsPage> createState() => _ClearedBillsPageState();
}

class _ClearedBillsPageState extends State<ClearedBillsPage> {
  late final ClearedBillsProvider _provider;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _provider = ClearedBillsProvider();
    _loadData();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _provider.loadClearedBills(salesmanIdentifier);
    }
    if (mounted) {
      setState(() => _hasLoaded = true);
    }
  }

  Future<void> _refreshData() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _provider.refreshClearedBills(salesmanIdentifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: Consumer<ClearedBillsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && !_hasLoaded) {
              return _buildLoadingState();
            }

            if (provider.hasError) {
              return _buildErrorState(provider.errorMessage);
            }

            if (provider.clearedBills.isEmpty && _hasLoaded) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.pepsiBlue,
              child: Column(
                children: [
                  _buildSummaryCard(provider),
                  Expanded(child: _buildBillList(provider.clearedBills)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Previous Day Collection',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            'Bills cleared today',
            style: GoogleFonts.poppins(
              fontSize: 12,
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

  Widget _buildSummaryCard(ClearedBillsProvider provider) {
    final totalCash = provider.totalCashCollected;
    final totalCrates = provider.totalCratesReturned;
    final clearedCount = provider.fullyClearedCount;
    final partialCount = provider.partialPaymentCount;
    final totalEntries = provider.clearedBills.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Main summary container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.pepsiBlue,
                  AppColors.pepsiBlueLight.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pepsiBlue.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cash collected - hero section
                if (totalCash > 0) ...[
                  Text(
                    'Rs. ${formatCashAmount(totalCash)}',
                    style: AppTextStyles.billingTotal.copyWith(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Cash Collected Today',
                    style: AppTextStyles.helperText.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 14),
                ],
                // Stats row inside the gradient card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInlineStatItem(
                      icon: Icons.receipt_long_outlined,
                      value: '$totalEntries',
                      label: 'Total',
                    ),
                    _buildStatDivider(),
                    _buildInlineStatItem(
                      icon: Icons.check_circle_outline,
                      value: '$clearedCount',
                      label: 'Cleared',
                    ),
                    if (partialCount > 0) ...[
                      _buildStatDivider(),
                      _buildInlineStatItem(
                        icon: Icons.timelapse_outlined,
                        value: '$partialCount',
                        label: 'Partial',
                      ),
                    ],
                    if (totalCrates > 0) ...[
                      _buildStatDivider(),
                      _buildInlineStatItem(
                        icon: Icons.recycling_outlined,
                        value: '$totalCrates',
                        label: 'MT',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.productItemName.copyWith(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.helperText.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildBillList(List<ClearedBill> bills) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TapScaleWrapper(
            onTap: () => _showBillDetail(bill),
            child: _buildBillCard(bill),
          ),
        );
      },
    );
  }

  Widget _buildBillCard(ClearedBill bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final isPartial = bill.isPartialPayment;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPartial
              ? Colors.orange.shade200.withValues(alpha: 0.7)
              : AppColors.gray300.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: customer name & status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  toTitleCase(bill.customerName),
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPartial
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPartial
                        ? Colors.orange.shade300
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPartial ? Icons.timelapse_outlined : Icons.check_circle,
                      color: isPartial
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPartial ? 'Partial' : 'Cleared',
                      style: AppTextStyles.helperText.copyWith(
                        color: isPartial
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bill info row
          Row(
            children: [
              _buildInfoChip(
                Icons.calendar_today_outlined,
                'Bill: ${formatDateShort(bill.originalDate)}',
                AppColors.gray500,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.inventory_2_outlined,
                '$totalItems items',
                AppColors.gray500,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.access_time_outlined,
                bill.formattedClearedTime,
                AppColors.gray500,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Payment info container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPartial
                  ? Colors.orange.shade50.withValues(alpha: 0.5)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Amount received row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount paid today
                    if (bill.amountPaidToday > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: isPartial
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rs. ${formatCashAmount(bill.amountPaidToday)}',
                            style: AppTextStyles.productItemTotal.copyWith(
                              color: isPartial
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPartial) ...[
                            const SizedBox(width: 4),
                            Text(
                              'received',
                              style: AppTextStyles.helperText.copyWith(
                                color: Colors.orange.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.pepsiBlue,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cash already paid',
                            style: AppTextStyles.helperText.copyWith(
                              color: AppColors.pepsiBlue,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                    // Crates returned
                    if (bill.cratesReturnedToday > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.recycling_outlined,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${bill.cratesReturnedToday} MT',
                            style: AppTextStyles.productItemTotal.copyWith(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Remaining amount for partial payments
                if (isPartial && bill.remainingAmountAfterPayment > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pending_outlined,
                          color: Colors.red.shade400,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Rs. ${formatCashAmount(bill.remainingAmountAfterPayment)} remaining',
                          style: AppTextStyles.helperText.copyWith(
                            color: Colors.red.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.helperText.copyWith(color: color, fontSize: 12),
        ),
      ],
    );
  }

  void _showBillDetail(ClearedBill bill) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ClearedBillDetailDialog(clearedBill: bill);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
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
            Icon(Icons.error_outline, color: AppColors.pepsiRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load cleared bills',
              style: AppTextStyles.productItemName.copyWith(
                color: AppColors.pepsiRed,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.pepsiBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.pepsiBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Cleared Bills',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No previous day bills have been cleared today yet.',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
