import 'package:animations/animations.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/features/checkout/presentation/pages/checkout_page.dart';
import 'package:ch_atta_traders_billing_application/features/products/providers/product_provider.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _productListScrollController = ScrollController();
  bool _isCheckoutVisible = false;
  List<Product> _filteredProducts = [];
  bool _hasInternetConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _initConnectivity();
    _setupConnectivityListener();
    // Load products from Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      // Auto-connect to printer if saved
      _autoConnectToPrinter();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _productListScrollController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _filterProducts() {
    setState(() {
      // Trigger rebuild to apply filter
    });
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
        context.read<ProductProvider>().loadProducts();
      }
    }
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return allProducts;
    } else {
      return allProducts
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        // Apply filter to current products
        _filteredProducts = _getFilteredProducts(productProvider.products);

        final int selectedCount = BillingCalculations.countSelectedProducts(
          productProvider.products,
        );

        // Show no internet state
        if (!_hasInternetConnection) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: _buildAppBar(selectedCount),
            body: _buildNoInternetState(),
          );
        }

        // Show loading indicator
        if (productProvider.isLoading) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: _buildAppBar(selectedCount),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.pepsiBlue),
            ),
          );
        }

        // Show error state
        if (productProvider.state == ProductState.error) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: _buildAppBar(selectedCount),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.pepsiRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    productProvider.errorMessage ?? 'Failed to load products',
                    style: AppTextStyles.helperText,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => productProvider.refreshProducts(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: _buildAppBar(selectedCount),
          body: Column(children: [_buildSearchBar(), _buildProductList()]),
        );
      },
    );
  }

  // ========== Business Logic Methods =

  /// Automatically connects to saved printer using PrinterService
  void _autoConnectToPrinter() {
    // Run in background without blocking UI
    PrinterService()
        .autoConnect()
        .then((success) {
          if (success && mounted) {
            CustomSnackBar.show(
              context,
              message: 'Printer connected automatically',
              type: SnackBarType.success,
            );
          }
        })
        .catchError((e) {
          debugPrint('Error during auto-connect: $e');
          // Silent fail - don't show error to user for auto-connect
        });
  }

  void _incrementQuantity(int index) {
    context.read<ProductProvider>().incrementQuantity(index);
  }

  void _decrementQuantity(int index) {
    context.read<ProductProvider>().decrementQuantity(index);
  }

  int get _grandTotal {
    final products = context.read<ProductProvider>().products;
    return BillingCalculations.calculateGrandTotal(products);
  }

  void _showCheckoutBottomSheet() {
    if (_grandTotal == 0) {
      _showNoItemsSnackBar();
      return;
    }

    setState(() {
      _isCheckoutVisible = true;
    });

    final products = context.read<ProductProvider>().products;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // This handles safe area internally
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CheckoutPage(
            products: products,
            onPrint: () {
              _handlePrintBill();
              Navigator.pop(context);
            },
            onDismiss: () {
              Navigator.pop(context);
            },
          ),
        );
      },
    ).whenComplete(() {
      setState(() {
        _isCheckoutVisible = false;
      });
    });
  }

  void _handlePrintBill() {
    context.read<ProductProvider>().resetAllQuantities();
    _searchController.clear();
    if (_productListScrollController.hasClients) {
      _productListScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showNoItemsSnackBar() {
    CustomSnackBar.show(
      context,
      message: 'No items to print',
      type: SnackBarType.warning,
    );
  }

  void _showQuickQuantityDialog(Product product, int index) {
    final quantityController = TextEditingController(
      text: product.quantity > 0 ? product.quantity.toString() : '',
    );

    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) => Dialog(
        backgroundColor: AppColors.pepsiWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuantityDialogTitle(),
                const SizedBox(height: 8),
                _buildQuantityDialogProductName(product.name),
                const SizedBox(height: 24),
                _buildQuantityQuickButtons(index, quantityController),
                const SizedBox(height: 16),
                _buildQuantityTextField(quantityController),
                const SizedBox(height: 24),
                _buildQuantityDialogActions(index, quantityController),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Delay disposal to ensure TextField is done using the controller
      Future.delayed(const Duration(milliseconds: 100), () {
        quantityController.dispose();
      });
    });
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
          : (!_hasInternetConnection || selectedCount == 0
                ? 'New Order'
                : 'GT Rs. ${formatCashAmount(_grandTotal)}'),
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
            borderRadius: BorderRadius.circular(8),
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
        controller: _productListScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          final products = context.read<ProductProvider>().products;
          final originalIndex = products.indexOf(product);
          return _buildProductItem(product, originalIndex);
        },
      ),
    );
  }

  // ========== Quantity Dialog Building Methods ==========

  Widget _buildQuantityDialogTitle() {
    return Text(
      'Select Quantity',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
    );
  }

  Widget _buildQuantityDialogProductName(String productName) {
    return Text(
      productName,
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 14,
        color: AppColors.gray500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildQuantityQuickButtons(
    int index,
    TextEditingController controller,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildQuantityButton(5, index, controller)),
            const SizedBox(width: 12),
            Expanded(child: _buildQuantityButton(10, index, controller)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildQuantityButton(20, index, controller)),
            const SizedBox(width: 12),
            Expanded(child: _buildQuantityButton(50, index, controller)),
          ],
        ),
        const SizedBox(height: 12),
        _buildQuantityButton(100, index, controller),
      ],
    );
  }

  Widget _buildQuantityButton(
    int quantity,
    int index,
    TextEditingController controller,
  ) {
    return ElevatedButton(
      onPressed: () {
        final provider = context.read<ProductProvider>();
        final currentQuantity = provider.products[index].quantity;
        final difference = quantity - currentQuantity;

        if (difference > 0) {
          for (int i = 0; i < difference; i++) {
            provider.incrementQuantity(index);
          }
        } else if (difference < 0) {
          for (int i = 0; i < difference.abs(); i++) {
            provider.decrementQuantity(index);
          }
        }
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.pepsiBlue.withValues(alpha: 0.1),
        foregroundColor: AppColors.pepsiBlue,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.pepsiBlue, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        quantity.toString(),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQuantityTextField(TextEditingController controller) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionHandleColor: AppColors.pepsiBlueLight,
          selectionColor: AppColors.textSecondary,
          cursorColor: AppColors.pepsiBlueLight,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.start,
        style: AppTextStyles.inputText.copyWith(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: AppColors.pepsiBlue,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: "Enter quantity",
          hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 15),
          prefixIcon: const Icon(Icons.edit_outlined, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.gray300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.pepsiBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityDialogActions(
    int index,
    TextEditingController controller,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gray500,
              side: const BorderSide(color: AppColors.gray300, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                final provider = context.read<ProductProvider>();
                final currentQuantity = provider.products[index].quantity;
                final difference = quantity - currentQuantity;

                if (difference > 0) {
                  for (int i = 0; i < difference; i++) {
                    provider.incrementQuantity(index);
                  }
                } else if (difference < 0) {
                  for (int i = 0; i < difference.abs(); i++) {
                    provider.decrementQuantity(index);
                  }
                }
              } else if (quantity == 0) {
                // Set to 0 by decrementing to 0
                final provider = context.read<ProductProvider>();
                final currentQuantity = provider.products[index].quantity;
                for (int i = 0; i < currentQuantity; i++) {
                  provider.decrementQuantity(index);
                }
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pepsiBlue,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Set Quantity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ========== Product Card Building Methods ==========

  Widget _buildProductItem(Product product, int index) {
    final isUnavailable = !product.isAvailable;
    final isSelected = product.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _buildProductCardDecoration(isUnavailable, isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnavailable
              ? null
              : () => _showQuickQuantityDialog(product, index),
          borderRadius: BorderRadius.circular(8),
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
      borderRadius: BorderRadius.circular(8),
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
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
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
