import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:flutter/foundation.dart';

/// Repository for handling product data operations with Firestore.
///
/// This class follows the Repository pattern to abstract data access
/// and provide a clean API for the ViewModel layer.
class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for products
  static const String _collectionName = 'products';

  /// Predefined product order - products will be sorted in this order.
  /// Products not in this list will appear at the bottom.
  static const List<String> _productOrder = [
    // Frequently Used Products
    'Pepsi 1500ml',
    'Pepsi 250ml RB',
    'Pepsi NR 300ml',
    'Sting 250ml RB',
    'Sting 500ml',
    'Sting NR 300ml',
    'Slice 200ml TP',
    'Aquafina 1500ml',
    'Revive NR 300ml',
    'Murree Sparklet 1500ml',
    'Murree Sparklet 500ml',
    'Shezan 250ml RB',

    // Carbonated Drinks — 1500ml
    'Big Apple 1500ml',
    'Coke 1500ml',
    'Master Cola 1500ml',

    // Carbonated Drinks — 300ml (NR)
    'Bigapple NR 300ml',
    'Master Cola NR 300ml',

    // Juices
    'Slice 1000ml TP',
    'Tops Tangy 250ml',
    'Shezan 250ml TP',

    // Cans
    'Pepsi Can 330ml',
    'Sting Can 330ml',

    // Carbonated Drinks — 2250ml
    'Pepsi 2250ml',
    'Master Cola 2250ml',

    // Carbonated Drinks — 1000ml
    'Pepsi 1000ml',

    // 500ml Bottles
    'Pepsi 500ml',
    'Gatorade 500ml',

    // Water
    'Aquafina 500ml',
    'Aquafina 19L',
    'Nestle 1500ml',
    'Master Water',
  ];

  /// Fetches all products from Firestore.
  ///
  /// Returns a list of [Product] objects sorted according to the predefined order.
  Future<List<Product>> fetchProducts() async {
    try {
      debugPrint('Fetching products from Firestore...');

      final querySnapshot = await _firestore.collection(_collectionName).get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No products found in Firestore');
        return [];
      }

      final products = querySnapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint('Product document: ${doc.id} -> $data');

        return Product(
          name: doc.id, // Document ID is the product name
          price: (data['price'] as num?)?.toInt() ?? 0,
          quantity: 0, // Default quantity is 0 for ordering
          isAvailable: data['isAvailable'] as bool? ?? true,
          type: data['type'] as String? ?? 'others',
        );
      }).toList();

      // Sort products according to predefined order
      products.sort((a, b) {
        final aIndex = _productOrder.indexOf(a.name);
        final bIndex = _productOrder.indexOf(b.name);

        // If both products are in the predefined list, sort by their position
        if (aIndex != -1 && bIndex != -1) {
          return aIndex.compareTo(bIndex);
        }
        // If only 'a' is in the list, it comes first
        if (aIndex != -1) return -1;
        // If only 'b' is in the list, it comes first
        if (bIndex != -1) return 1;
        // If neither is in the list, sort alphabetically
        return a.name.compareTo(b.name);
      });

      debugPrint('Fetched ${products.length} products from Firestore');
      return products;
    } catch (e, stackTrace) {
      debugPrint('Error fetching products: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }
}
