import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // ========== Business Logic Methods ==========

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No items to print'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showBillPrintedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill printed and order reset')),
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
      style: const TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
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
      padding: const EdgeInsets.all(16),
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
          filled: true,
          fillColor: Colors.grey[100],
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.pepsiRed, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          return _buildProductItem(_products[index], index);
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
            ? Colors.grey.withValues(alpha: 0.3)
            : (isSelected ? AppColors.pepsiBlue : Colors.transparent),
        width: 2,
      ),
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
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
