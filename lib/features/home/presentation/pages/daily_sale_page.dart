import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/daily_sales_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailySalePage extends StatefulWidget {
  const DailySalePage({super.key});

  @override
  State<DailySalePage> createState() => _DailySalePageState();
}

class _DailySalePageState extends State<DailySalePage> {
  late final DailySalesProvider _salesProvider;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _salesProvider = DailySalesProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load sales every time the page comes into view
    if (!_hasLoadedOnce || ModalRoute.of(context)?.isCurrent == true) {
      _hasLoadedOnce = true;
      _loadSales();
    }
  }

  @override
  void dispose() {
    _salesProvider.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    final salesmanName = await AppPreferences.instance.salesmanName;
    if (salesmanName != null && salesmanName.isNotEmpty) {
      await _salesProvider.loadDailySales(salesmanName, DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _salesProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: Consumer<DailySalesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildLoadingState();
            }

            if (provider.hasError) {
              return _buildErrorState(provider.errorMessage);
            }

            if (provider.sales.isEmpty) {
              return _buildEmptyState();
            }

            return _buildSaleList(provider.sales);
          },
        ),
      ),
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('Daily Sales', style: AppTextStyles.pageTitleBlack),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.pepsiRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.pepsiRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Sales',
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSales,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
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

  Widget _buildSaleList(List<SaleHistory> saleHistory) {
    return RefreshIndicator(
      onRefresh: _loadSales,
      color: AppColors.pepsiBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: saleHistory.length,
        itemBuilder: (context, index) {
          final sale = saleHistory[index];
          return _buildSalesCard(context, sale);
        },
      ),
    );
  }

  // ========== Empty State Building Methods ==========

  Widget _buildEmptyStateIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.pepsiBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        size: 40,
        color: AppColors.pepsiBlue,
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

  Widget _buildSalesCard(BuildContext context, SaleHistory sale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.pepsiBlue.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showBillDetails(context, sale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCardContent(sale),
        ),
      ),
    );
  }

  Widget _buildCardContent(SaleHistory sale) {
    final totalItems = BillingCalculations.calculateTotalItems(sale.products);
    final grandTotal =
        BillingCalculations.calculateGrandTotal(sale.products) - sale.discount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          toTitleCase(sale.customerName),
          style: AppTextStyles.productItemName.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: AppColors.gray500),
            const SizedBox(width: 4),
            Text(
              sale.formattedTime,
              style: AppTextStyles.helperText.copyWith(
                fontSize: 16,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                _buildAmountBadge(grandTotal),
                const SizedBox(width: 8),
                _buildItemCountBadge(totalItems),
              ],
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.gray400,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountBadge(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Rs. ${formatCashAmount(amount)}',
        style: AppTextStyles.productItemTotal.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.pepsiBlueLight,
          letterSpacing: -0.3,
        ),
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

  // ========== Dialog Methods ==========

  void _showBillDetails(BuildContext context, SaleHistory sale) {
    showDialog(
      context: context,
      builder: (context) =>
          BillDetailsDialog(bill: sale, accentColor: AppColors.pepsiBlueLight),
    );
  }
}
