import 'package:animations/animations.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/daily_sales_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class DailySalePage extends StatefulWidget {
  const DailySalePage({super.key});

  @override
  State<DailySalePage> createState() => _DailySalePageState();
}

class _DailySalePageState extends State<DailySalePage> {
  late final DailySalesProvider _salesProvider;
  bool _hasLoadedOnce = false;
  bool _hasInternetConnection = true;
  int? _deletingIndex;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _salesProvider = DailySalesProvider();
    _initConnectivity();
    _setupConnectivityListener();
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

  /// Initialize connectivity check on app start
  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      setState(() => _hasInternetConnection = false);
    }
  }

  /// Setup listener for connectivity changes
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  /// Update connection status based on connectivity results
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection =
        results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    if (mounted && _hasInternetConnection != hasConnection) {
      setState(() => _hasInternetConnection = hasConnection);

      // Reload data when connection is restored
      if (hasConnection && _hasLoadedOnce) {
        _loadSales();
      }
    }
  }

  @override
  void dispose() {
    _salesProvider.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSales() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _salesProvider.loadDailySales(salesmanIdentifier, DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _salesProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: !_hasInternetConnection
            ? _buildNoInternetState()
            : Consumer<DailySalesProvider>(
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
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.pepsiBlue, AppColors.pepsiBlueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pepsiBlue.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loadSales,
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: const Text(
                  'Refresh List',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.pepsiWhite,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
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
          return _buildSalesCard(context, sale, index);
        },
      ),
    );
  }

  // ========== Empty State Building Methods ==========

  Widget _buildEmptyStateIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.pepsiBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        size: 48,
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

  Widget _buildNoInternetState() {
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
                color: AppColors.pepsiBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: AppColors.pepsiBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for connection. Will update automatically when restored.',
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

  // ========== Card Building Methods ==========

  Widget _buildSalesCard(BuildContext context, SaleHistory sale, int index) {
    // Hide delete button and divider for credit type bills (converted from credit)
    final bool isCreditBill = sale.billType == BillType.credit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.pepsiBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showBillDetails(context, sale),
                borderRadius: BorderRadius.circular(8),
                child: _buildCardContent(sale),
              ),
            ),
            // Only show divider and delete button for cash bills (not converted from credit)
            if (!isCreditBill) ...[
              const SizedBox(width: 16),
              Container(height: 90, width: 1.5, color: AppColors.gray300),
              const SizedBox(width: 16),
              _buildDeleteButton(index),
            ],
          ],
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
          formatCustomerName(sale.customerName),
          style: AppTextStyles.productItemName.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 17, color: AppColors.gray500),
            const SizedBox(width: 6),
            Text(
              sale.formattedTime,
              style: AppTextStyles.helperText.copyWith(
                fontSize: 15,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAmountBadge(grandTotal),
            const SizedBox(width: 8),
            _buildItemCountBadge(totalItems),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountBadge(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Rs. ${formatCashAmount(amount)}',
        style: AppTextStyles.productItemTotal.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.pepsiBlueLight,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildItemCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300, width: 0.5),
      ),
      child: Text(
        '$count items',
        style: AppTextStyles.helperText.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  // ========== Dialog Methods ==========

  Widget _buildDeleteButton(int index) {
    final isDeleting = _deletingIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDeleting ? null : () => _showDeleteConfirmation(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.pepsiRedLight.withValues(
              alpha: isDeleting ? 0.05 : 0.1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isDeleting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.pepsiRedLight,
                    ),
                  ),
                )
              : Icon(
                  Icons.delete_outline,
                  color: AppColors.pepsiRedLight.withValues(
                    alpha: isDeleting ? 0.4 : 1.0,
                  ),
                  size: 24,
                ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final sale = _salesProvider.sales[index];
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) => _buildDeleteConfirmationDialog(sale, index),
    );
  }

  Dialog _buildDeleteConfirmationDialog(SaleHistory sale, int index) {
    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: AppColors.pepsiRedLight,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Delete Sale?',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Permanently delete ${formatCustomerName(sale.customerName)}\'s sale? This will remove it from sales history.',
              textAlign: TextAlign.center,
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.gray300,
                          width: 1.5,
                        ),
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
                        _deleteSalePermanently(index);
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSalePermanently(int index) async {
    setState(() => _deletingIndex = index);

    final saleToDelete = _salesProvider.sales[index];

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _deletingIndex = null);
      _showErrorSnackBar('Salesman identifier not found. Please log in again.');
      return;
    }

    try {
      final success = await _salesProvider.deleteSale(
        sale: saleToDelete,
        salesmanName: salesmanIdentifier,
      );

      if (success) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Sale deleted.',
            type: SnackBarType.success,
          );
        }
      } else {
        _showErrorSnackBar('Failed to delete sale.');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting sale: ${e.toString()}');
    }

    setState(() => _deletingIndex = null);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      CustomSnackBar.show(context, message: message, type: SnackBarType.error);
    }
  }

  void _showBillDetails(BuildContext context, SaleHistory sale) {
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          BillDetailsDialog(bill: sale, accentColor: AppColors.pepsiBlueLight),
    );
  }
}
