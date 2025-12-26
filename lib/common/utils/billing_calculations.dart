import 'package:ch_atta_traders_billing_application/data/models/product.dart';

/// Utility class for billing calculations
class BillingCalculations {
  /// Calculate total number of items from a list of products
  static int calculateTotalItems(List<Product> products) {
    return products.fold<int>(0, (sum, product) => sum + product.quantity);
  }

  /// Calculate grand total from a list of products
  static int calculateGrandTotal(List<Product> products) {
    return products.fold<int>(
      0,
      (sum, product) => sum + (product.price * product.quantity),
    );
  }

  /// Get only selected products (quantity > 0)
  static List<Product> getSelectedProducts(List<Product> products) {
    return products.where((p) => p.quantity > 0).toList();
  }

  /// Count selected products (quantity > 0)
  static int countSelectedProducts(List<Product> products) {
    return products.where((p) => p.quantity > 0).length;
  }

  /// Calculate total crates from RB (Returnable Bottle) products
  static int calculateTotalCrates(List<Product> products) {
    return products
        .where((product) => product.name.toUpperCase().endsWith('RB'))
        .fold<int>(0, (sum, product) => sum + product.quantity);
  }
}
