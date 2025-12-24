import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/features/checkout/presentation/pages/checkout_page.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:flutter/material.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  bool _isCheckoutVisible = false;
  late final List<Product> _products = Product.getDummyProducts();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = _products;
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where((product) => product.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int selectedCount = BillingCalculations.countSelectedProducts(
      _products,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(selectedCount),
      body: Column(children: [_buildSearchBar(), _buildProductList()]),
    );
  }

  // ========== Business Logic Methods =
  void _incrementQuantity(int index) {
    setState(() {
      _products[index].quantity++;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (_products[index].quantity > 0) {
        _products[index].quantity--;
      }
    });
  }

  int get _grandTotal {
    return BillingCalculations.calculateGrandTotal(_products);
  }

  void _showCheckoutBottomSheet() {
    if (_grandTotal == 0) {
      _showNoItemsSnackBar();
      return;
    }

    setState(() {
      _isCheckoutVisible = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CheckoutPage(
          customerController: _customerNameController,
          products: _products,
          onPrint: () {
            _searchController.clear();
            _customerNameController.clear();
            _handlePrintBill();
            Navigator.pop(context);
          },
          onDismiss: () {
            Navigator.pop(context);
          },
        ),
      ),
    ).whenComplete(() {
      setState(() {
        _isCheckoutVisible = false;
      });
    });
  }

  void _handlePrintBill() {
    setState(() {
      for (final p in _products) {
        p.quantity = 0;
      }
      _customerNameController.clear();
    });
    _showBillPrintedSnackBar();
  }

  void _showNoItemsSnackBar() {
    CustomSnackBar.show(
      context,
      message: 'No items to print',
      type: SnackBarType.warning,
    );
  }

  void _showBillPrintedSnackBar() {
    CustomSnackBar.show(
      context,
      message: 'Bill printed and order reset',
      type: SnackBarType.success,
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar(int selectedCount) {
    return AppBar(
      title: _buildAppBarTitle(selectedCount),
      actions: [_buildPrintButton()],
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  Widget _buildAppBarTitle(int selectedCount) {
    return Text(
      _isCheckoutVisible
          ? 'CHECKOUT'
          : (selectedCount > 0
                ? 'GT Rs. ${formatNumber(_grandTotal)}'
                : 'New Order'),
      style: AppTextStyles.pageTitleBlack,
    );
  }

  Widget _buildPrintButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.pepsiBlue, AppColors.pepsiRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showCheckoutBottomSheet,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print, color: AppColors.pepsiWhite, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Print',
                    style: TextStyle(
                      color: AppColors.pepsiWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.pepsiWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: AppColors.textSecondary,
                selectionHandleColor: AppColors.textSecondary,
                selectionColor: AppColors.textSecondary,
              ),
            ),
            child: TextField(
              cursorColor: AppColors.textSecondary,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        iconSize: 24,
                        icon: Icon(
                          Icons.clear,
                          color: AppColors.pepsiRed.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.pepsiRed,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                isDense: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList() {
    if (_filteredProducts.isEmpty) {
      return Expanded(
        child: Center(
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
                    Icons.search_off,
                    size: 40,
                    color: AppColors.pepsiBlue,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Products Found',
                  style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: AppTextStyles.helperText.copyWith(
                    color: AppColors.gray500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          final originalIndex = _products.indexOf(product);
          return _buildProductItem(product, originalIndex);
        },
      ),
    );
  }

  // ========== Product Card Building Methods ==========

  Widget _buildProductItem(Product product, int index) {
    final isUnavailable = product.price == 0;
    final isSelected = product.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _buildProductCardDecoration(isUnavailable, isSelected),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(product, index, isUnavailable),
            const SizedBox(height: 8),
            _buildProductFooter(product, isUnavailable, isSelected),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildProductCardDecoration(
    bool isUnavailable,
    bool isSelected,
  ) {
    return BoxDecoration(
      color: isUnavailable ? Colors.grey[100] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isUnavailable
            ? AppColors.gray300
            : (isSelected ? AppColors.pepsiBlue : AppColors.gray300),
        width: 1.5,
      ),
      boxShadow: !isUnavailable
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  Widget _buildProductHeader(Product product, int index, bool isUnavailable) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductName(product.name, isUnavailable),
        const SizedBox(width: 5),
        _buildQuantityControls(product, index, isUnavailable),
      ],
    );
  }

  Widget _buildProductName(String name, bool isUnavailable) {
    return Expanded(
      child: Text(
        name,
        semanticsLabel: name,
        style: AppTextStyles.productItemName.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isUnavailable
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black,
        ),
      ),
    );
  }

  Widget _buildQuantityControls(
    Product product,
    int index,
    bool isUnavailable,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isUnavailable
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnavailable
              ? AppColors.textSecondary.withValues(alpha: 0.3)
              : AppColors.textSecondary,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildDecrementButton(index, isUnavailable),
          _buildQuantityDisplay(product.quantity, isUnavailable),
          _buildIncrementButton(index, isUnavailable),
        ],
      ),
    );
  }

  Widget _buildDecrementButton(int index, bool isUnavailable) {
    return IconButton(
      tooltip: 'Decrease quantity',
      onPressed: isUnavailable ? null : () => _decrementQuantity(index),
      icon: const Icon(Icons.remove_circle),
      color: isUnavailable
          ? AppColors.pepsiRed.withValues(alpha: 0.3)
          : AppColors.pepsiRed,
      iconSize: 28,
    );
  }

  Widget _buildQuantityDisplay(int quantity, bool isUnavailable) {
    return Container(
      width: 40,
      alignment: Alignment.center,
      child: Semantics(
        label: 'Quantity',
        value: '$quantity',
        child: Text(
          '$quantity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isUnavailable
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildIncrementButton(int index, bool isUnavailable) {
    return IconButton(
      tooltip: 'Increase quantity',
      onPressed: isUnavailable ? null : () => _incrementQuantity(index),
      icon: const Icon(Icons.add_circle),
      color: isUnavailable
          ? AppColors.pepsiBlue.withValues(alpha: 0.3)
          : AppColors.pepsiBlue,
      iconSize: 28,
    );
  }

  Widget _buildProductFooter(
    Product product,
    bool isUnavailable,
    bool isSelected,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildUnitPrice(product.price, isUnavailable),
        if (isSelected && !isUnavailable)
          _buildTotalPrice(product.price * product.quantity),
      ],
    );
  }

  Widget _buildUnitPrice(int price, bool isUnavailable) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnavailable
              ? AppColors.pepsiBlue.withValues(alpha: 0.4)
              : AppColors.pepsiBlue,
          width: 1,
        ),
      ),
      child: Text(
        'Rs. $price',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isUnavailable
              ? AppColors.pepsiBlue.withValues(alpha: 0.4)
              : AppColors.pepsiBlue,
        ),
      ),
    );
  }

  Widget _buildTotalPrice(int total) {
    return Text(
      'Rs. $total',
      style: AppTextStyles.productItemTotal.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
