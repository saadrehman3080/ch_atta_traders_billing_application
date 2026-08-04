import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:ch_atta_traders_billing_application/features/home/providers/daily_progress_provider.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/daily_progress_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Page showing the salesman's daily progress summary.
/// Fifth tab in the bottom navigation bar.
class DailyProgressPage extends StatefulWidget {
  const DailyProgressPage({super.key});

  @override
  State<DailyProgressPage> createState() => _DailyProgressPageState();
}

class _DailyProgressPageState extends State<DailyProgressPage> {
  late final DailyProgressProvider _progressProvider;
  bool _hasLoadedOnce = false;
  bool _hasInternetConnection = true;
  String? _salesmanDocId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _progressProvider = DailyProgressProvider();
    _progressProvider.addListener(_onDataChanged);
    _initConnectivity();
    _setupConnectivityListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce || ModalRoute.of(context)?.isCurrent == true) {
      _hasLoadedOnce = true;
      _loadProgress();
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() => _hasInternetConnection = false);
      }
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection =
        results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    if (mounted && _hasInternetConnection != hasConnection) {
      setState(() => _hasInternetConnection = hasConnection);
      if (hasConnection && _hasLoadedOnce) {
        _loadProgress();
      }
    }
  }

  @override
  void dispose() {
    _progressProvider.removeListener(_onDataChanged);
    _progressProvider.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProgress() async {
    final docId = await AppPreferences.instance.salesmanDocId;
    if (!mounted) return;

    if (docId != null && docId.isNotEmpty) {
      _salesmanDocId = docId;
      await _progressProvider.loadProgressList(docId);
    }
  }

  Future<void> _refreshProgress() async {
    if (_salesmanDocId != null && _salesmanDocId!.isNotEmpty) {
      await _progressProvider.refreshProgressList(_salesmanDocId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _progressProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: !_hasInternetConnection
            ? _buildNoInternetState()
            : Consumer<DailyProgressProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.progressList.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (provider.hasError) {
                    return _buildErrorState(provider.errorMessage);
                  }

                  if (provider.progressList.isEmpty && !provider.isLoading) {
                    return _buildEmptyState();
                  }

                  return _buildContent(provider);
                },
              ),
      ),
    );
  }

  // ========== AppBar ==========

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('My Progress', style: AppTextStyles.pageTitleBlack),
      centerTitle: false,
      actions: [
        if (_hasInternetConnection && _progressProvider.progressList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 12,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pepsiBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.pepsiBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.pepsiBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_progressProvider.totalRecordCount}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _progressProvider.totalRecordCount == 1 ? 'Day' : 'Days',
                      style: GoogleFonts.poppins(
                        color: AppColors.pepsiBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.gray300, height: 1),
      ),
    );
  }

  // ========== Content ==========

  Widget _buildContent(DailyProgressProvider provider) {
    final list = provider.progressList;

    return RefreshIndicator(
      onRefresh: _refreshProgress,
      color: AppColors.pepsiBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // All-time MT & Cash balance card
            _buildOverallBalanceCard(provider),
            const SizedBox(height: 16),

            // Monthly summary card
            _buildMonthlySummaryCard(provider),
            const SizedBox(height: 20),

            // History header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Daily Records',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            // Record count indicator
            if (provider.totalRecordCount > list.length)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Showing ${list.length} of ${provider.allRecentRecords.length} recent'
                  ' (${provider.totalRecordCount} total)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

            // List of daily records
            ...list.map((record) => _buildDayCard(record)),

            // Load More button
            if (provider.hasMoreRecords)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => provider.loadMore(),
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.pepsiBlue,
                    ),
                    label: Text(
                      'Load More (${provider.allRecentRecords.length - list.length} remaining)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.pepsiBlue,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.pepsiBlue.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========== Overall Balance Card (All-Time MT & Cash) ==========

  Widget _buildOverallBalanceCard(DailyProgressProvider provider) {
    final netMt = provider.totalNetMt;
    final netCash = provider.totalNetCash;
    final isMtShort = netMt < 0;
    final isCashShort = netCash > 0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon + title + records pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Total Balance',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                // const Spacer(),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 10,
                //     vertical: 4,
                //   ),
                //   decoration: BoxDecoration(
                //     color: Colors.white.withValues(alpha: 0.12),
                //     borderRadius: BorderRadius.circular(20),
                //   ),
                //   child: Text(
                //     '${provider.totalRecordCount} records',
                //     style: GoogleFonts.poppins(
                //       fontSize: 11,
                //       fontWeight: FontWeight.w500,
                //       color: Colors.white70,
                //     ),
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 20),

            // Cash section — left-aligned hero
            Text(
              'Cash',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(netCash.abs()),
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCashShort
                              ? Icons.arrow_downward_rounded
                              : netCash < 0
                              ? Icons.arrow_upward_rounded
                              : Icons.check_rounded,
                          size: 13,
                          color: isCashShort
                              ? Colors.redAccent.shade100
                              : netCash < 0
                              ? Colors.greenAccent
                              : Colors.white60,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isCashShort
                              ? 'Short'
                              : netCash < 0
                              ? 'Excess'
                              : 'Balanced',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCashShort
                                ? Colors.redAccent.shade100
                                : netCash < 0
                                ? Colors.greenAccent
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // MT — inline row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.bottleWater,
                    color: Colors.white60,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Empty Crates',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${netMt.abs()}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isMtShort
                          ? 'Short'
                          : netMt > 0
                          ? 'Excess'
                          : 'Balanced',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  // ========== Monthly Summary Card ==========

  Widget _buildMonthlySummaryCard(DailyProgressProvider provider) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: AppColors.pepsiBlue,
              ),
              const SizedBox(width: 8),
              Text(
                monthName,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pepsiBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${provider.monthlyDaysWorked} days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pepsiBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMonthStat(
                  'Total Sales',
                  _formatCurrency(provider.monthlySalesAmount),
                  AppColors.pepsiBlue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMonthStat(
                  'Items Sold',
                  '${provider.monthlyItemsSold}',
                  AppColors.pepsiBlueLight,
                ),
              ),
              Expanded(
                child: _buildMonthStat(
                  'Expenses',
                  _formatCurrency(provider.monthlyTotalExpenses),
                  AppColors.pepsiRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ========== Daily Record Card ==========

  Widget _buildDayCard(DailyProgress record) {
    return GestureDetector(
      onTap: () => _showBreakdownDialog(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Date and status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.pepsiBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateLabel(record.date),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        record.isCompleted ? 'Completed' : 'In Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: record.isCompleted
                              ? AppColors.textSuccess
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray400,
                    size: 24,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Divider
              Container(
                height: 1,
                color: AppColors.gray300.withValues(alpha: 0.4),
              ),

              const SizedBox(height: 14),

              // Summary row 1 - Sales and Cash
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Total Sales',
                      _formatCurrency(record.totalSalesAmount),
                      AppColors.pepsiBlue,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Cash Received',
                      _formatCurrency(record.cashReceived),
                      AppColors.textSuccess,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Summary row 2 - Items and Expenses
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Items Sold',
                      '${record.totalItemsSold}',
                      AppColors.pepsiBlueLight,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Expenses',
                      _formatCurrency(record.totalExpenses),
                      AppColors.pepsiRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Summary row 3 - MT and Final
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      record.emptyCrates.short > 0
                          ? 'MT Short'
                          : record.emptyCrates.excess > 0
                          ? 'MT Excess'
                          : 'MT Balanced',
                      record.emptyCrates.short > 0
                          ? '${record.emptyCrates.short}'
                          : record.emptyCrates.excess > 0
                          ? '${record.emptyCrates.excess}'
                          : '0',
                      record.emptyCrates.short > 0
                          ? Colors.orange
                          : record.emptyCrates.excess > 0
                          ? AppColors.textSuccess
                          : AppColors.pepsiBlue,
                      icon: record.emptyCrates.short > 0
                          ? Icons.arrow_downward_rounded
                          : record.emptyCrates.excess > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      record.finalAmount > 0
                          ? 'Short'
                          : record.finalAmount < 0
                          ? 'Excess'
                          : 'Balanced',
                      _formatCurrency(record.finalAmount.abs()),
                      record.finalAmount > 0
                          ? AppColors.pepsiRed
                          : record.finalAmount < 0
                          ? AppColors.textSuccess
                          : AppColors.pepsiBlue,
                      icon: record.finalAmount > 0
                          ? Icons.arrow_downward_rounded
                          : record.finalAmount < 0
                          ? Icons.arrow_upward_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    Color valueColor, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 3),
            ],
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========== Show Breakdown Dialog ==========

  void _showBreakdownDialog(DailyProgress record) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return DailyProgressDetailDialog(record: record);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  // ========== State Widgets ==========

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
              'Error Loading Progress',
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
              onPressed: _loadProgress,
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
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.trending_up_outlined,
                size: 48,
                color: AppColors.pepsiBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Progress Data',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Your daily progress records will appear here',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
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
                onPressed: _loadProgress,
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: const Text(
                  'Refresh',
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

  // ========== Helpers ==========

  String _formatDateLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, EEEE').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'Rs ${formatter.format(amount)}';
  }
}
