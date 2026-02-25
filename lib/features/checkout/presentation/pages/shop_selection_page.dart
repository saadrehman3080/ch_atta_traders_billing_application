import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/database/shop_database_helper.dart';
import 'package:ch_atta_traders_billing_application/data/models/shop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A page that displays a searchable list of shops filtered by route.
///
/// The user can select a route via a segmented button (Kallar 1/2/3),
/// search shops by name, and tap a shop to select it as the customer.
/// Returns the selected [Shop] via Navigator.pop.
class ShopSelectionPage extends StatefulWidget {
  const ShopSelectionPage({super.key});

  @override
  State<ShopSelectionPage> createState() => _ShopSelectionPageState();
}

class _ShopSelectionPageState extends State<ShopSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ShopDatabaseHelper _dbHelper = ShopDatabaseHelper.instance;

  String _selectedRoute = 'KALLAR SYEDAN-1';
  List<Shop> _shops = [];
  List<Shop> _filteredShops = [];
  bool _isLoading = true;
  String? _expandedShopCode;

  // Route options
  static const List<String> _routes = [
    'KALLAR SYEDAN-1',
    'KALLAR SYEDAN-2',
    'KALLAR SYEDAN-3',
  ];

  static const List<String> _routeLabels = ['Kallar 1', 'Kallar 2', 'Kallar 3'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSavedRoute();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Loads the previously selected route from SharedPreferences.
  Future<void> _loadSavedRoute() async {
    final savedRoute = await AppPreferences.instance.selectedShopRoute;
    if (mounted) {
      setState(() => _selectedRoute = savedRoute);
      _loadShops();
    }
  }

  /// Loads shops for the selected route from the database.
  Future<void> _loadShops() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final shops = await _dbHelper.getShopsByRoute(_selectedRoute);
      if (mounted) {
        setState(() {
          _shops = shops;
          _filteredShops = shops;
          _isLoading = false;
          _expandedShopCode = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading shops: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shops = [];
          _filteredShops = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load shops. Please try again.'),
          ),
        );
      }
    }
  }

  /// Handles search text changes.
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredShops = _shops;
        _expandedShopCode = null;
      });
    } else {
      final filtered = _shops
          .where(
            (shop) =>
                shop.outletName.toUpperCase().contains(query.toUpperCase()) ||
                shop.owner.toUpperCase().contains(query.toUpperCase()) ||
                shop.outletAddress.toUpperCase().contains(query.toUpperCase()),
          )
          .toList();
      setState(() {
        _filteredShops = filtered;
        _expandedShopCode = null;
      });
    }
  }

  /// Handles route selection change.
  Future<void> _onRouteChanged(Set<String> newSelection) async {
    final route = newSelection.first;
    setState(() => _selectedRoute = route);
    try {
      await AppPreferences.instance.setSelectedShopRoute(route);
    } catch (e) {
      debugPrint('Failed to persist route selection: $e');
    }
    if (!mounted) return;
    _searchController.clear();
    _loadShops();
  }

  /// Toggles the expanded dropdown for a shop card.
  void _toggleExpanded(Shop shop) {
    setState(() {
      if (_expandedShopCode == shop.outletCode) {
        _expandedShopCode = null;
      } else {
        _expandedShopCode = shop.outletCode;
      }
    });
  }

  /// Selects a shop and returns it to the checkout page.
  void _selectShop(Shop shop) {
    Navigator.of(context).pop(shop);
  }

  /// Formats a phone number with + prefix.
  String _formatPhone(String phone) {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    return '+$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildRouteSelector(),
          _buildSearchBar(),
          Expanded(child: _buildShopList()),
        ],
      ),
    );
  }

  // ========== AppBar ==========

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
            'Select Shop',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            'Choose a shop as customer',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        if (!_isLoading && _filteredShops.isNotEmpty)
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
                      decoration: const BoxDecoration(
                        color: AppColors.pepsiBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_filteredShops.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Shops',
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
        child: Container(
          color: AppColors.gray300.withValues(alpha: 0.5),
          height: 1,
        ),
      ),
    );
  }

  // ========== Route Selector ==========

  Widget _buildRouteSelector() {
    return Container(
      color: AppColors.pepsiWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: List.generate(
            _routes.length,
            (index) => ButtonSegment<String>(
              value: _routes[index],
              label: Text(_routeLabels[index]),
              icon: const Icon(Icons.route, size: 16),
            ),
          ),
          selected: {_selectedRoute},
          onSelectionChanged: _onRouteChanged,
          style: _buildSegmentedButtonStyle(),
        ),
      ),
    );
  }

  ButtonStyle _buildSegmentedButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.pepsiBlue;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return Colors.black87;
      }),
      side: WidgetStateProperty.all(
        const BorderSide(color: AppColors.gray300, width: 1),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      ),
      textStyle: WidgetStateProperty.all(
        GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ========== Search Bar ==========

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.pepsiWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: AppTextStyles.inputText.copyWith(
            color: Colors.black87,
            fontSize: 14,
          ),
          cursorColor: AppColors.pepsiBlue,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.gray100,
            hintText: 'Search shop name, owner, or address...',
            hintStyle: AppTextStyles.inputHint.copyWith(
              fontSize: 13,
              color: AppColors.gray400,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.gray500,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 18,
                      color: AppColors.gray500,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    },
                  )
                : null,
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
    );
  }

  // ========== Shop List ==========

  Widget _buildShopList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pepsiBlue),
      );
    }

    if (_filteredShops.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _filteredShops.length,
      itemBuilder: (context, index) {
        final shop = _filteredShops[index];
        final isExpanded = _expandedShopCode == shop.outletCode;
        return _buildShopCard(shop, isExpanded);
      },
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
                Icons.store_mall_directory_outlined,
                color: AppColors.pepsiBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No Shops Found'
                  : 'No Shops in Route',
              style: AppTextStyles.productItemName.copyWith(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'Select a different route to see shops',
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

  // ========== Shop Card ==========

  Widget _buildShopCard(Shop shop, bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? AppColors.pepsiBlue.withValues(alpha: 0.25)
                : AppColors.gray300.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isExpanded ? 0.06 : 0.03),
              blurRadius: isExpanded ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Tappable header — selects the shop as customer
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _selectShop(shop),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: Radius.circular(isExpanded ? 0 : 14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _buildCardHeader(shop, isExpanded),
                ),
              ),
            ),
            // Expandable details dropdown
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetailsDropdown(shop),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(Shop shop, bool isExpanded) {
    return Row(
      children: [
        // Shop icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.pepsiBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront,
            size: 20,
            color: AppColors.pepsiBlue,
          ),
        ),
        const SizedBox(width: 12),
        // Shop name and address
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toTitleCase(shop.outletName),
                style: AppTextStyles.productItemName.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: AppColors.gray500,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      shop.outletAddress,
                      style: AppTextStyles.helperText.copyWith(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Dropdown toggle
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleExpanded(shop),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isExpanded
                    ? AppColors.pepsiBlue.withValues(alpha: 0.08)
                    : AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: isExpanded ? AppColors.pepsiBlue : AppColors.gray400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsDropdown(Shop shop) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray100.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: AppColors.gray300.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Details grid
          _buildDetailItem(
            Icons.badge_outlined,
            'Outlet Code',
            shop.outletCode,
          ),
          const SizedBox(height: 8),
          _buildDetailItem(
            Icons.location_on_outlined,
            'Address',
            shop.outletAddress,
          ),
          const SizedBox(height: 8),
          _buildDetailItem(Icons.location_city_outlined, 'Town', shop.town),
          if (shop.owner.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailItem(Icons.person_outline, 'Owner', shop.owner),
          ],
          if (shop.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailItem(
              Icons.phone_outlined,
              'Phone',
              _formatPhone(shop.phone),
            ),
          ],
          if (shop.latitude != null && shop.longitude != null) ...[
            const SizedBox(height: 8),
            _buildDetailItem(
              Icons.my_location_outlined,
              'Location',
              '${shop.latitude?.toStringAsFixed(6) ?? 'N/A'}, ${shop.longitude?.toStringAsFixed(6) ?? 'N/A'}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.pepsiBlue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTextStyles.helperText.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.productItemName.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
