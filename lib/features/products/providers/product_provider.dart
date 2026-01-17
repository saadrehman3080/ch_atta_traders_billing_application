import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/product_repository.dart';

/// Product loading state enum
enum ProductState { initial, loading, loaded, error }

/// ViewModel for product operations.
///
/// This class follows the MVVM pattern, managing product state
/// and coordinating between the View and Repository layers.
class ProductProvider extends ChangeNotifier {
  final ProductRepository _repository;

  ProductProvider({ProductRepository? repository})
    : _repository = repository ?? ProductRepository();

  // ========== State Management ==========
  ProductState _state = ProductState.initial;
  List<Product> _products = [];
  String? _errorMessage;

  /// Current product loading state
  ProductState get state => _state;

  /// List of all products
  List<Product> get products => _products;

  /// Error message if loading failed
  String? get errorMessage => _errorMessage;

  /// Whether products are being loaded
  bool get isLoading => _state == ProductState.loading;

  /// Whether products have been loaded
  bool get isLoaded => _state == ProductState.loaded;

  // ========== Product Methods ==========

  /// Fetches all products from the repository.
  ///
  /// Returns true if loading was successful, false otherwise.
  Future<bool> loadProducts() async {
    _setState(ProductState.loading);
    _errorMessage = null;

    try {
      final products = await _repository.fetchProducts();

      if (products.isNotEmpty) {
        _products = products;
        _setState(ProductState.loaded);
        debugPrint('Products loaded successfully: ${products.length} items');
        return true;
      } else {
        _errorMessage = 'No products available';
        _setState(ProductState.error);
        debugPrint('No products found in repository');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to load products. Please try again.';
      _setState(ProductState.error);
      debugPrint('Error loading products: $e');
      return false;
    }
  }

  /// Refreshes the product list from the repository.
  Future<bool> refreshProducts() async {
    debugPrint('Refreshing products...');
    return await loadProducts();
  }

  /// Updates the quantity of a product.
  ///
  /// [index] - The index of the product in the products list
  /// [quantity] - The new quantity value
  void updateProductQuantity(int index, int quantity) {
    if (index >= 0 && index < _products.length) {
      _products[index] = _products[index].copyWith(quantity: quantity);
      notifyListeners();
    }
  }

  /// Increments the quantity of a product.
  ///
  /// [index] - The index of the product in the products list
  void incrementQuantity(int index) {
    if (index >= 0 && index < _products.length) {
      final newQuantity = _products[index].quantity + 1;
      updateProductQuantity(index, newQuantity);
    }
  }

  /// Decrements the quantity of a product.
  ///
  /// [index] - The index of the product in the products list
  void decrementQuantity(int index) {
    if (index >= 0 && index < _products.length) {
      final currentQuantity = _products[index].quantity;
      if (currentQuantity > 0) {
        updateProductQuantity(index, currentQuantity - 1);
      }
    }
  }

  /// Resets all product quantities to zero.
  void resetAllQuantities() {
    for (int i = 0; i < _products.length; i++) {
      _products[i] = _products[i].copyWith(quantity: 0);
    }
    notifyListeners();
    debugPrint('All product quantities reset');
  }

  /// Clears all products and resets state (used on logout).
  void clearProducts() {
    _products = [];
    _state = ProductState.initial;
    _errorMessage = null;
    notifyListeners();
    debugPrint('Products cleared on logout');
  }

  // ========== Private Methods ==========

  void _setState(ProductState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('ProductProvider disposed');
    super.dispose();
  }
}
