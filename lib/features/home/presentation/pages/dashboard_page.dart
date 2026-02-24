import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:ch_atta_traders_billing_application/features/auth/providers/auth_provider.dart';
import 'package:ch_atta_traders_billing_application/features/home/providers/dashboard_provider.dart';
import 'package:ch_atta_traders_billing_application/features/products/providers/product_provider.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToOrder;

  const DashboardPage({super.key, this.onNavigateToOrder});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  late final DashboardProvider _dashboardProvider;
  late final PrinterService _printerService;
  String _salesmanName = 'Salesman';
  bool _hasInternetConnection = true;
  bool _hasAnonymousPrintAccess = false; // From Firebase - controls visibility
  bool _isAnonymousPrintEnabled = false; // Toggle state
  bool _isSkipCustomerNameDefault = false; // Skip customer name toggle state
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardProvider = DashboardProvider();
    _printerService = PrinterService();
    _loadSalesmanName();
    _loadAnonymousPrintSettings();
    _initConnectivity();
    _setupConnectivityListener();
    _dashboardProvider.loadDashboardData();
    _printerService.initialize();
    // Listen to printer service changes
    _printerService.addListener(_onPrinterStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _printerService.removeListener(_onPrinterStateChanged);
    _dashboardProvider.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check connection when app comes to foreground
      _printerService.checkExistingConnection();
    }
  }

  /// Callback when printer state changes
  void _onPrinterStateChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when printer state changes
      });
    }
  }

  Future<void> _loadSalesmanName() async {
    final name = await AppPreferences.instance.salesmanName;
    if (name != null && mounted) {
      setState(() {
        _salesmanName = name;
      });
    }
  }

  /// Load anonymous print access and enabled state
  Future<void> _loadAnonymousPrintSettings() async {
    final hasAccess = await AppPreferences.instance.hasAnonymousPrintAccess;
    final isEnabled = await AppPreferences.instance.isAnonymousPrintEnabled;
    final skipCustomer =
        await AppPreferences.instance.isSkipCustomerNameDefault;
    if (mounted) {
      setState(() {
        _hasAnonymousPrintAccess = hasAccess;
        _isAnonymousPrintEnabled = isEnabled;
        _isSkipCustomerNameDefault = skipCustomer;
      });
    }
  }

  /// Toggle anonymous print on/off
  Future<void> _toggleAnonymousPrint() async {
    final newValue = !_isAnonymousPrintEnabled;
    await AppPreferences.instance.setAnonymousPrintEnabled(newValue);
    if (mounted) {
      setState(() {
        _isAnonymousPrintEnabled = newValue;
      });
    }
  }

  /// Toggle skip customer name default on/off
  Future<void> _toggleSkipCustomerName() async {
    final newValue = !_isSkipCustomerNameDefault;
    await AppPreferences.instance.setSkipCustomerNameDefault(newValue);
    if (mounted) {
      setState(() {
        _isSkipCustomerNameDefault = newValue;
      });
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
      if (hasConnection) {
        _dashboardProvider.refreshDashboardData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _dashboardProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(context),
        body: RefreshIndicator(
          onRefresh: () => _dashboardProvider.refreshDashboardData(),
          color: AppColors.pepsiBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildTodayCollectionCard(),
                _buildPreviousDayCollectionCard(),
                _buildPrintersCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== Main UI Building Methods ==========

  /// Check if the dashboard has actual data to display
  bool get _hasActualData {
    final data = _dashboardProvider.dashboardData;
    if (data == null) return false;
    return data.totalCollection != 0 ||
        data.totalItemsSold != 0 ||
        data.totalMtRemaining != 0 ||
        data.totalCredit != 0 ||
        data.totalDiscount != 0 ||
        data.customersServed != 0;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      title: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          // When there's no data or all values zero, show current date and day
          // to keep theme consistent without duplicating the greeting
          if (!_hasActualData) {
            final now = DateTime.now();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(now),
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.gray500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM, yyyy').format(now),
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _salesmanName,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
      centerTitle: false,
      actions: [
        _buildConnectionIndicator(),
        const SizedBox(width: 8),
        _buildLogoutButton(context),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.gray300.withValues(alpha: 0.5),
          height: 1,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ========== App Bar Action Building Methods ==========

  Widget _buildConnectionIndicator() {
    final isConnected = _printerService.state.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.08)
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : AppColors.gray400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Printer' : 'Offline',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isConnected ? Colors.green[700] : AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.pepsiRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: AppColors.pepsiRed,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ========== Collection Card Building Methods ==========

  Widget _buildTodayCollectionCard() {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // Show no internet state first
        if (!_hasInternetConnection) {
          return _buildNoInternetCard();
        }

        // Show loading card only on initial load (when no data exists)
        if (provider.isLoading && provider.dashboardData == null) {
          return _buildLoadingCard();
        }

        if (provider.hasError) {
          return _buildErrorCard(provider.errorMessage ?? 'Unknown error');
        }

        final data = provider.dashboardData;

        if (data == null) {
          return _buildNoDataCard();
        }

        // Check if all values are zero (no bills generated yet)
        final allValuesZero =
            data.totalCollection == 0 &&
            data.totalItemsSold == 0 &&
            data.totalMtRemaining == 0 &&
            data.totalCredit == 0 &&
            data.totalDiscount == 0 &&
            data.customersServed == 0;

        if (allValuesZero) {
          return _buildWelcomeCard();
        }

        // Show data card during refresh (when data exists and loading)
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: _buildCollectionCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollectionLabel(),
              const SizedBox(height: 6),
              _buildCollectionAmount(data),
              const SizedBox(height: 12),
              _buildStatsGrid(data),
              const SizedBox(height: 10),
              _buildCustomersServedSection(data),
              const SizedBox(height: 5),
              //_buildNewBillButton(),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _buildCollectionCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.pepsiBlue,
          AppColors.pepsiBlueLight.withValues(alpha: 0.95),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.pepsiBlue.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
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

  Widget _buildCollectionAmount(DashboardData data) {
    return Text(
      'Rs. ${formatCashAmount(data.totalCollection)}',
      style: AppTextStyles.billingTotal.copyWith(fontSize: 32),
    );
  }

  Widget _buildStatsGrid(DashboardData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Items Sold',
                '${data.totalItemsSold}',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                'MT Remaining',
                '${data.totalMtRemaining}',
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
                'Rs. ${formatCashAmount(data.totalCredit)}',
                Icons.credit_card_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                'Discount',
                'Rs. ${formatCashAmount(data.totalDiscount)}',
                Icons.discount_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomersServedSection(DashboardData data) {
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
            '${data.customersServed}',
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white70, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.helperText.copyWith(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.productItemName.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the previous day collection card showing cash and MT collected
  /// from previous day credit bills. Only shown if there's previous day data.
  Widget _buildPreviousDayCollectionCard() {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // Don't show if no internet, loading, or error
        if (!_hasInternetConnection ||
            (provider.isLoading && provider.dashboardData == null) ||
            provider.hasError) {
          return const SizedBox.shrink();
        }

        final data = provider.dashboardData;

        // Don't show if no data or no previous day data
        if (data == null || !data.hasPreviousDayData) {
          return const SizedBox.shrink();
        }

        final previousDayCash = data.previousDayCash ?? 0;
        final previousDayMt = data.previousDayMt ?? 0;
        final totalCash = data.totalCollection + previousDayCash;

        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.pepsiBlue.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pepsiBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: AppColors.pepsiBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Previous Day Collection',
                    style: AppTextStyles.productItemName.copyWith(
                      color: AppColors.pepsiBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cash Collection Section (only show if previousDayCash > 0)
              if (previousDayCash > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.pepsiBlue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pepsiBlue.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Previous Day Cash
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Previous Day Cash',
                            style: AppTextStyles.helperText.copyWith(
                              color: AppColors.gray500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Rs. ${formatCashAmount(previousDayCash)}',
                            style: AppTextStyles.productItemName.copyWith(
                              color: AppColors.pepsiBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Today's Collection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Collection",
                            style: AppTextStyles.helperText.copyWith(
                              color: AppColors.gray500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Rs. ${formatCashAmount(data.totalCollection)}',
                            style: AppTextStyles.productItemName.copyWith(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppColors.gray300),
                      ),
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Cash',
                            style: AppTextStyles.productItemName.copyWith(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rs. ${formatCashAmount(totalCash)}',
                            style: AppTextStyles.billingTotal.copyWith(
                              color: AppColors.pepsiBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // MT Collection Section (only show if previousDayMt > 0)
              if (previousDayMt > 0) ...[
                if (previousDayCash > 0) const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.recycling_outlined,
                            color: Colors.orange.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Previous Day MT Collected',
                            style: AppTextStyles.helperText.copyWith(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$previousDayMt',
                        style: AppTextStyles.productItemName.copyWith(
                          color: Colors.orange.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoInternetCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
      decoration: _buildCollectionCardDecoration(),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: AppTextStyles.pageTitleBlack.copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for connection. Will update automatically when restored.',
              style: AppTextStyles.helperText.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
      decoration: _buildCollectionCardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.pepsiRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.pepsiRed.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: const Color.fromARGB(255, 145, 107, 107),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load dashboard',
            style: AppTextStyles.productItemName.copyWith(
              color: AppColors.pepsiRed,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: AppTextStyles.helperText.copyWith(
              color: AppColors.gray300,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _dashboardProvider.refreshDashboardData(),
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pepsiRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
      decoration: _buildCollectionCardDecoration(),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assessment_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start creating bills to see your dashboard',
              style: AppTextStyles.helperText.copyWith(
                color: Colors.white70,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildNewBillButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final greeting = _getGreeting();
    final greetingIcon = _getGreetingIcon();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
      decoration: _buildCollectionCardDecoration(),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(greetingIcon, color: Colors.white, size: 45),
            ),
            const SizedBox(height: 18),
            Text(
              '$greeting, $_salesmanName!',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Ready to start your day?',
              style: AppTextStyles.helperText.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first bill to begin tracking',
              style: AppTextStyles.helperText.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildNewBillButton(),
          ],
        ),
      ),
    );
  }

  // ========== Printers Card Building Methods ==========

  Widget _buildPrintersCard() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray300.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildPrintersSection(),
    );
  }

  Widget _buildPrintersSection() {
    final printerState = _printerService.state;

    if (printerState.isScanning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrintersSectionHeader(),
          const SizedBox(height: 12),
          _buildScanningPrinters(),
          _buildAnonymousPrintToggle(),
          _buildSkipCustomerNameToggle(),
        ],
      );
    }

    if (printerState.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrintersSectionHeader(),
          const SizedBox(height: 12),
          _buildPrinterError(),
          _buildAnonymousPrintToggle(),
          _buildSkipCustomerNameToggle(),
        ],
      );
    }

    if (printerState.availablePrinters.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrintersSectionHeader(),
          const SizedBox(height: 12),
          _buildNoPrintersFound(),
          _buildAnonymousPrintToggle(),
          _buildSkipCustomerNameToggle(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPrintersSectionHeader(),
        const SizedBox(height: 12),
        ...printerState.availablePrinters.map(
          (printer) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPrinterItem(printer),
          ),
        ),
        _buildAnonymousPrintToggle(),
        _buildSkipCustomerNameToggle(),
      ],
    );
  }

  /// Builds the anonymous print toggle button
  /// Only shown if user has access to this feature (from Firebase)
  Widget _buildAnonymousPrintToggle() {
    // Don't show button if user doesn't have access to this feature
    if (!_hasAnonymousPrintAccess) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleAnonymousPrint,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isAnonymousPrintEnabled
                  ? AppColors.pepsiBlue.withValues(alpha: 0.05)
                  : AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isAnonymousPrintEnabled
                    ? AppColors.pepsiBlue.withValues(alpha: 0.3)
                    : AppColors.gray300.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isAnonymousPrintEnabled
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined,
                  color: _isAnonymousPrintEnabled
                      ? AppColors.pepsiBlue
                      : AppColors.gray400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anonymous Print',
                        style: AppTextStyles.productItemName.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isAnonymousPrintEnabled
                              ? AppColors.pepsiBlue
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAnonymousPrintEnabled
                            ? 'Receipts print without business name, salesman identity, and time'
                            : 'Hide business name, use ID instead of name, and remove time from receipts',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 11,
                          color: _isAnonymousPrintEnabled
                              ? AppColors.pepsiBlue
                              : AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: _isAnonymousPrintEnabled
                        ? AppColors.pepsiBlue
                        : AppColors.gray300,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: _isAnonymousPrintEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the skip customer name toggle
  /// Always visible for all users
  Widget _buildSkipCustomerNameToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleSkipCustomerName,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isSkipCustomerNameDefault
                  ? AppColors.pepsiBlue.withValues(alpha: 0.05)
                  : AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSkipCustomerNameDefault
                    ? AppColors.pepsiBlue.withValues(alpha: 0.3)
                    : AppColors.gray300.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSkipCustomerNameDefault
                      ? Icons.person_off
                      : Icons.person_off_outlined,
                  color: _isSkipCustomerNameDefault
                      ? AppColors.pepsiBlue
                      : AppColors.gray400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skip Customer Name',
                        style: AppTextStyles.productItemName.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isSkipCustomerNameDefault
                              ? AppColors.pepsiBlue
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSkipCustomerNameDefault
                            ? 'Customer name is skipped by default on new orders'
                            : 'Enable to auto-skip customer name on checkout',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 11,
                          color: _isSkipCustomerNameDefault
                              ? AppColors.pepsiBlue
                              : AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: _isSkipCustomerNameDefault
                        ? AppColors.pepsiBlue
                        : AppColors.gray300,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: _isSkipCustomerNameDefault
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPrintersFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray300.withValues(alpha: 0.5)),
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
    final printerCount = _printerService.state.availablePrinters.length;
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
        if (printerCount > 0)
          Text(
            '$printerCount',
            style: AppTextStyles.helperText.copyWith(
              color: AppColors.pepsiBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      return Icons.wb_sunny_outlined; // Morning sun
    } else if (hour < 16) {
      return Icons.wb_sunny; // Afternoon sun
    } else if (hour < 19) {
      return Icons.wb_twilight; // Evening
    } else {
      return Icons.nightlight_outlined; // Night
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Disconnect printer if connected
      if (_printerService.state.isConnected) {
        await _printerService.disconnect();
        debugPrint('Printer disconnected on logout');
      }

      // Clear products to reset grand total
      if (context.mounted) {
        context.read<ProductProvider>().clearProducts();
      }

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

  Future<void> _handleConnectToPrinter(BluetoothInfo printer) async {
    final success = await _printerService.connectToPrinter(printer);
    if (mounted) {
      if (success) {
        CustomSnackBar.show(
          context,
          message: 'Connected to ${printer.name}',
          type: SnackBarType.success,
        );
      } else {
        final errorMsg =
            _printerService.state.errorMessage ??
            'Failed to connect to ${printer.name}';
        CustomSnackBar.show(
          context,
          message: errorMsg,
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _handleDisconnectPrinter() async {
    final success = await _printerService.disconnect();
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: success
            ? 'Printer disconnected'
            : 'Failed to disconnect printer',
        type: success ? SnackBarType.info : SnackBarType.error,
      );
    }
  }

  Future<void> _handleRefreshPrinters() async {
    await _printerService.scanForPrinters();

    // If there's an error related to permissions, show a helpful snackbar
    if (_printerService.state.hasError &&
        _printerService.state.errorMessage?.contains('permission') == true) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Bluetooth permissions required.',
          type: SnackBarType.error,
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => openAppSettings(),
            textColor: AppColors.pepsiWhite,
          ),
        );
      }
    }
  }

  Widget _buildScanningPrinters() {
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
          CircularProgressIndicator(color: AppColors.pepsiBlue, strokeWidth: 3),
          const SizedBox(height: 14),
          Text(
            'Scanning for printers...',
            style: AppTextStyles.helperText.copyWith(
              color: AppColors.gray500,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.pepsiRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.pepsiRed.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.pepsiRed, size: 32),
          const SizedBox(height: 10),
          Text(
            _printerService.state.errorMessage ?? 'Error',
            style: AppTextStyles.helperText.copyWith(
              color: AppColors.pepsiRed,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _handleRefreshPrinters(),
            icon: Icon(Icons.refresh, size: 16),
            label: Text(
              'Retry',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pepsiRed,
              backgroundColor: AppColors.pepsiRed.withValues(alpha: 0.1),
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

  Widget _buildPrinterItem(BluetoothInfo printer) {
    final printerState = _printerService.state;
    final isConnected = _printerService.isPrinterConnected(printer.macAdress);
    final isCurrentlyConnecting = _printerService.isPrinterConnecting(
      printer.macAdress,
    );
    final isAnyPrinterConnecting = printerState.isAnyPrinterConnecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.pepsiBlue.withValues(alpha: 0.05)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? AppColors.pepsiBlue.withValues(alpha: 0.3)
              : AppColors.gray300.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.print : Icons.print_outlined,
            color: isConnected ? AppColors.pepsiBlue : AppColors.gray400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printer.name,
                  style: AppTextStyles.productItemName.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isConnected ? AppColors.pepsiBlue : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected ? 'Connected' : printer.macAdress,
                  style: AppTextStyles.helperText.copyWith(
                    fontSize: 11,
                    color: isConnected
                        ? AppColors.pepsiBlue
                        : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentlyConnecting)
            Padding(
              padding: const EdgeInsets.only(right: 24.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pepsiBlue,
                ),
              ),
            )
          else
            _buildPrinterActionButton(
              printer,
              isConnected,
              isAnyPrinterConnecting,
            ),
        ],
      ),
    );
  }

  Widget _buildPrinterActionButton(
    BluetoothInfo printer,
    bool isConnected,
    bool isAnyPrinterConnecting,
  ) {
    // Disable button if another printer is connecting
    final isDisabled = isAnyPrinterConnecting && !isConnected;

    return TextButton(
      onPressed: isDisabled
          ? null
          : () => isConnected
                ? _handleDisconnectPrinter()
                : _handleConnectToPrinter(printer),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: isDisabled
            ? AppColors.gray300
            : isConnected
            ? AppColors.pepsiRed.withValues(alpha: 0.1)
            : AppColors.pepsiBlue.withValues(alpha: 0.1),
        disabledBackgroundColor: AppColors.gray300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        isConnected ? 'Disconnect' : 'Connect',
        style: AppTextStyles.helperText.copyWith(
          fontSize: 11,
          color: isDisabled
              ? AppColors.gray400
              : isConnected
              ? AppColors.pepsiRed
              : AppColors.pepsiBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
