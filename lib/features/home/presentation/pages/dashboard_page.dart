import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:ch_atta_traders_billing_application/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToOrder;

  const DashboardPage({super.key, this.onNavigateToOrder});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardData _dashboardData;
  String _salesmanName = 'Salesman';
  // final bool hasPrinters = false; // TODO: Replace with actual printer check

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadSalesmanName();
  }

  void _loadDashboardData() {
    // TODO: Replace with actual data from Firebase/local storage
    _dashboardData = DashboardData.getDummyData();
  }

  Future<void> _loadSalesmanName() async {
    final name = await AppPreferences.instance.salesmanName;
    if (name != null && mounted) {
      setState(() {
        _salesmanName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [_buildTodayCollectionCard(), _buildPrintersCard()],
        ),
      ),
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: _buildAppBarTitle(),
      centerTitle: false,
      actions: _buildAppBarActions(context),
      bottom: _buildAppBarBorder(),
    );
  }

  Widget _buildAppBarTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTA TRADERS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppColors.pepsiBlueLight,
          ),
        ),
        _buildSubtitleRow(),
      ],
    );
  }

  Widget _buildSubtitleRow() {
    return Row(
      children: [
        Text(
          '$_salesmanName • Salesman Panel',
          style: AppTextStyles.helperText.copyWith(
            fontSize: 12,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [_buildLogoutButton(context), const SizedBox(width: 12)];
  }

  PreferredSizeWidget _buildAppBarBorder() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.gray300),
    );
  }

  // ========== App Bar Action Building Methods ==========

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.pepsiRed.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout),
        color: AppColors.pepsiRed,
        iconSize: 20,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ========== Collection Card Building Methods ==========

  Widget _buildTodayCollectionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: _buildCollectionCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCollectionLabel(),
          const SizedBox(height: 6),
          _buildCollectionAmount(),
          const SizedBox(height: 12),
          _buildStatsGrid(),
          const SizedBox(height: 10),
          _buildCustomersServedSection(),
          const SizedBox(height: 10),
          _buildNewBillButton(),
        ],
      ),
    );
  }

  BoxDecoration _buildCollectionCardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          AppColors.pepsiBlueLight,
          AppColors.pepsiBlue,
          AppColors.pepsiRedLight,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildCollectionLabel() {
    return Text(
      "Today's Collection",
      style: AppTextStyles.helperText.copyWith(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }

  Widget _buildCollectionAmount() {
    return Text(
      'Rs. ${formatCashAmount(_dashboardData.totalCollection)}',
      style: AppTextStyles.billingTotal.copyWith(fontSize: 32),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Items Sold',
                '${_dashboardData.totalItemsSold}',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                'MT Remaining',
                '${_dashboardData.totalMtRemaining}',
                Icons.recycling_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Credit',
                'Rs. ${formatCashAmount(_dashboardData.totalCredit)}',
                Icons.credit_card_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                'Discount',
                'Rs. ${formatCashAmount(_dashboardData.totalDiscount)}',
                Icons.discount_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomersServedSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'Customers Served:',
            style: AppTextStyles.helperText.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_dashboardData.customersServed}',
            style: AppTextStyles.productItemName.copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.helperText.copyWith(
                  color: Colors.white70,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTextStyles.productItemName.copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Printers Card Building Methods ==========

  Widget _buildPrintersCard() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray300, width: 1.5),
      ),
      child: _buildPrintersSection(),
    );
  }

  Widget _buildPrintersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPrintersSectionHeader(),
        const SizedBox(height: 12),
        _buildNoPrintersFound(),
      ],
    );
  }

  Widget _buildNoPrintersFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray300, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.pepsiBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.print_disabled,
              color: AppColors.pepsiBlue,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Printer',
            style: AppTextStyles.productItemName.copyWith(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please connect a printer to continue',
            style: AppTextStyles.helperText.copyWith(
              color: AppColors.gray500,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _handleRefreshPrinters(),
            icon: Icon(Icons.refresh, size: 16),
            label: Text(
              'Refresh',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pepsiBlue,
              backgroundColor: AppColors.pepsiBlue.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintersSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.print_outlined,
              color: AppColors.pepsiBlueLight,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Available Printers',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Icon(Icons.refresh, color: AppColors.gray500, size: 18),
      ],
    );
  }

  Widget _buildNewBillButton() {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleNewBill,
        style: _buildNewBillButtonStyle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNewBillIcon(),
            const SizedBox(width: 8),
            _buildNewBillLabel(),
          ],
        ),
      ),
    );
  }

  ButtonStyle _buildNewBillButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.pepsiWhite,
      foregroundColor: AppColors.pepsiBlueLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildNewBillIcon() {
    return const Icon(Icons.add, color: AppColors.pepsiBlueLight, size: 24);
  }

  Widget _buildNewBillLabel() {
    return Text(
      'New Bill',
      style: AppTextStyles.smallButton.copyWith(
        color: AppColors.pepsiBlueLight,
      ),
    );
  }

  // ========== Business Logic Methods ==========

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Clear authentication state
      if (context.mounted) {
        context.read<AuthProvider>().logout();
      }

      // Navigate to login screen
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Still navigate to login even if cleanup fails
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  void _handleNewBill() {
    widget.onNavigateToOrder?.call();
  }

  void _handleRefreshPrinters() {
    // TODO: Implement refresh printers logic
  }

  // Widget _buildPrinterItem(String printerName, String printerStatus) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //     decoration: BoxDecoration(
  //       color: AppColors.gray50,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: AppColors.gray300, width: 1),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(
  //           Icons.print,
  //           color: printerStatus == 'Connected'
  //               ? AppColors.pepsiBlue
  //               : AppColors.gray400,
  //           size: 20,
  //         ),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 printerName,
  //                 style: AppTextStyles.productItemName.copyWith(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //               const SizedBox(height: 2),
  //               Text(
  //                 printerStatus,
  //                 style: AppTextStyles.helperText.copyWith(
  //                   fontSize: 11,
  //                   color: printerStatus == 'Connected'
  //                       ? AppColors.pepsiBlue
  //                       : AppColors.gray500,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         _buildPrinterActionButton(printerStatus),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildPrinterActionButton(String printerStatus) {
  //   return TextButton(
  //     onPressed: () => _handlePrinterAction(printerStatus),
  //     style: TextButton.styleFrom(
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //       minimumSize: Size.zero,
  //       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //     ),
  //     child: Text(
  //       printerStatus == 'Connected' ? 'Disconnect' : 'Connect',
  //       style: AppTextStyles.helperText.copyWith(
  //         fontSize: 11,
  //         color: printerStatus == 'Connected'
  //             ? AppColors.pepsiRed
  //             : AppColors.pepsiBlue,
  //         fontWeight: FontWeight.w600,
  //       ),
  //     ),
  //   );
  // }

  // void _handlePrinterAction(String printerStatus) {
  //   // TODO: Implement connect/disconnect printer logic
  // }
}
