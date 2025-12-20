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

  // TODO: Replace with Firebase data fetching
  late final List<Product> _products = Product.getDummyProducts();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to print'),
          duration: Duration(seconds: 2),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    // compute selection to decide whether to show the billing card
    final int selectedCount = BillingCalculations.countSelectedProducts(
      _products,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
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
        ),
        actions: [
          Padding(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print,
                          color: AppColors.pepsiWhite,
                          size: 20,
                        ),
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
          ),
        ],
        backgroundColor: AppColors.pepsiWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          displaySearchItems(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                return _buildProductItem(_products[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handlePrintBill() {
    // Reset all product quantities and clear the customer name
    setState(() {
      for (final p in _products) {
        p.quantity = 0;
      }
      _customerNameController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill printed and order reset')),
    );
  }

  // Build a single product item row/card
  Widget _buildProductItem(Product product, int index) {
    final isUnavailable = product.price == 0;
    final isSelected = product.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnavailable ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnavailable
              ? Colors.grey.withValues(alpha: 0.3)
              : (isSelected ? AppColors.pepsiBlue : Colors.transparent),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Info (name only)
                Expanded(
                  child: Text(
                    product.name,
                    semanticsLabel: product.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isUnavailable
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 5),
                // Quantity Controls (kept in a column so total can be shown below)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
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
                          IconButton(
                            tooltip: 'Decrease quantity',
                            onPressed: isUnavailable
                                ? null
                                : () => _decrementQuantity(index),
                            icon: const Icon(Icons.remove_circle),
                            color: isUnavailable
                                ? AppColors.pepsiRed.withValues(alpha: 0.3)
                                : AppColors.pepsiRed,
                            iconSize: 28,
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Semantics(
                              label: 'Quantity',
                              value: '${product.quantity}',
                              child: Text(
                                '${product.quantity}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isUnavailable
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Increase quantity',
                            onPressed: isUnavailable
                                ? null
                                : () => _incrementQuantity(index),
                            icon: const Icon(Icons.add_circle),
                            color: isUnavailable
                                ? AppColors.pepsiBlue.withValues(alpha: 0.3)
                                : AppColors.pepsiBlue,
                            iconSize: 28,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Price row: unit price (left) and total (right) — this row sits under the buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
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
                    'Rs. ${product.price}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isUnavailable
                          ? AppColors.pepsiBlue.withValues(alpha: 0.4)
                          : AppColors.pepsiBlue,
                    ),
                  ),
                ),
                if (isSelected && !isUnavailable)
                  Text(
                    'Rs. ${product.price * product.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Container displaySearchItems() {
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
}
