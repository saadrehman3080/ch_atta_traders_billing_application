import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/core/notifiers/nav_visibility_notifier.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/dashboard_page.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/daily_sale_page.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/credit_record_page.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/daily_progress_page.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/pages/order_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  void _navigateToOrderPage() {
    NavVisibilityNotifier.isVisible.value = true;
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _navigateToCreditPage() {
    NavVisibilityNotifier.isVisible.value = true;
    setState(() {
      _selectedIndex = 3;
    });
  }

  List<Widget> get _pages => [
    DashboardPage(
      onNavigateToOrder: _navigateToOrderPage,
      onNavigateToCredit: _navigateToCreditPage,
    ),
    const OrderPage(),
    const DailySalePage(),
    const CreditRecordPage(),
    const DailyProgressPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: NavVisibilityNotifier.isVisible,
        builder: (context, isVisible, child) {
          return AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isVisible ? null : 0,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.pepsiWhite,
            border: Border(
              top: BorderSide(
                color: AppColors.gray300.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.grid_view_outlined,
                    Icons.grid_view,
                    'Dashboard',
                  ),
                  _buildNavItem(
                    1,
                    Icons.shopping_cart_outlined,
                    Icons.shopping_cart,
                    'Order',
                  ),
                  _buildNavItem(
                    2,
                    Icons.history_outlined,
                    Icons.history,
                    'History',
                  ),
                  _buildNavItem(
                    3,
                    Icons.receipt_outlined,
                    Icons.receipt,
                    'Credit',
                  ),
                  _buildNavItem(
                    4,
                    Icons.trending_up_outlined,
                    Icons.trending_up,
                    'Progress',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            // Restore nav bar visibility on tab change
            NavVisibilityNotifier.isVisible.value = true;
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.pepsiBlue.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.pepsiBlue.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? AppColors.pepsiBlue : AppColors.gray400,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.pepsiBlue : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
