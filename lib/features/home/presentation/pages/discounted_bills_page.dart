import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/tap_scale_wrapper.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/features/home/providers/discounted_bills_provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Page showing all today's bills where a discount was applied.
/// Accessible by tapping the "Discount" stat container on the dashboard.
class DiscountedBillsPage extends StatefulWidget {
  const DiscountedBillsPage({super.key});

  @override
  State<DiscountedBillsPage> createState() => _DiscountedBillsPageState();
}

class _DiscountedBillsPageState extends State<DiscountedBillsPage> {
  late final DiscountedBillsProvider _provider;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _provider = DiscountedBillsProvider();
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
      await _provider.loadDiscountedBills(salesmanIdentifier);
    }
    if (mounted) {
      setState(() => _hasLoaded = true);
    }
  }

  Future<void> _refreshData() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _provider.refreshDiscountedBills(salesmanIdentifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: Consumer<DiscountedBillsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && !_hasLoaded) {
              return _buildLoadingState();
            }

            if (provider.hasError) {
              return _buildErrorState(provider.errorMessage);
            }

            if (provider.discountedBills.isEmpty && _hasLoaded) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.pepsiBlue,
              child: Column(
                children: [
                  _buildSummaryCard(provider),
                  Expanded(child: _buildBillList(provider.discountedBills)),
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
            'Discounted Bills',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            "Today's bills with discount",
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

  Widget _buildSummaryCard(DiscountedBillsProvider provider) {
    final totalDiscount = provider.totalDiscountAmount;
    final billCount = provider.discountedBills.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.pepsiBlue,
              AppColors.pepsiBlueLight.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.pepsiBlue.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Discount amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rs. ${formatCashAmount(totalDiscount)}',
                    style: AppTextStyles.billingTotal.copyWith(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Discount Today',
                    style: AppTextStyles.helperText.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Bill count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '$billCount',
                    style: AppTextStyles.productItemName.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    billCount == 1 ? 'Bill' : 'Bills',
                    style: AppTextStyles.helperText.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList(List<BillBase> bills) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TapScaleWrapper(
            onTap: () => _showBillDetails(bill),
            child: _buildBillCard(bill),
          ),
        );
      },
    );
  }

  Widget _buildBillCard(BillBase bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final grandTotal =
        BillingCalculations.calculateGrandTotal(bill.products) - bill.discount;
    final isCredit = bill is CreditHistory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray300.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: bill info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer name
                Text(
                  toTitleCase(bill.customerName),
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Time & items
                Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      size: 12,
                      color: AppColors.gray500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      bill.formattedTime,
                      style: AppTextStyles.helperText.copyWith(
                        color: AppColors.gray500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: AppColors.gray500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$totalItems items',
                      style: AppTextStyles.helperText.copyWith(
                        color: AppColors.gray500,
                        fontSize: 11,
                      ),
                    ),
                    if (isCredit) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pepsiRedLight.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.pepsiRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Credit',
                          style: AppTextStyles.helperText.copyWith(
                            color: AppColors.pepsiRed,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Amount
                Text(
                  'Rs. ${formatCashAmount(grandTotal)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    color: AppColors.pepsiBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Right: discount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.discount_outlined,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  '-${bill.discount}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBillDetails(BillBase bill) {
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          BillDetailsDialog(bill: bill, accentColor: AppColors.pepsiBlueLight),
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
              'Failed to load discounted bills',
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
                Icons.discount_outlined,
                color: AppColors.pepsiBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Discounted Bills',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No bills with discount have been created today.',
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
