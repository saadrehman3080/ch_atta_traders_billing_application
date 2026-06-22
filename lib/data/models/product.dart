/// Product types used to determine the store name on receipts.
/// - 'pepsi' → CH. ATTA TRADERS
/// - 'masterCola' → CH. SAAD TRADERS
/// - 'others' → No store name on receipt
class Product {
  final String name;
  final int price;
  int quantity;
  final bool isAvailable;
  final String type; // 'pepsi', 'masterCola', or 'others'
  final List<String> subtypes; // variant names fetched from database
  final Map<String, int> subtypeQuantities; // runtime quantities per variant

  /// Whether this product has subtypes/variants.
  ///
  /// This returns true even when the original subtype list isn't stored, but
  /// subtype quantities are present (e.g., when a bill is loaded from storage).
  bool get hasSubtypes => subtypes.isNotEmpty || subtypeQuantities.isNotEmpty;

  Product({
    required this.name,
    required this.price,
    this.quantity = 0,
    this.isAvailable = true,
    this.type = 'others',
    this.subtypes = const [],
    Map<String, int>? subtypeQuantities,
  }) : subtypeQuantities = subtypeQuantities ?? {};

  // Factory constructor to create Product from JSON (Firebase)
  factory Product.fromJson(Map<String, dynamic> json) {
    final subtypes =
        (json['subtypes'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    final subtypeQuantities = <String, int>{};
    if (json['subtypeQuantities'] != null) {
      (json['subtypeQuantities'] as Map<String, dynamic>).forEach((key, value) {
        subtypeQuantities[key] = (value as num).toInt();
      });
    }

    return Product(
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      type: json['type'] as String? ?? 'others',
      subtypes: subtypes,
      subtypeQuantities: subtypeQuantities,
    );
  }

  // Convert Product to JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'price': price,
      'quantity': quantity,
      'type': type,
    };
    if (subtypeQuantities.isNotEmpty) {
      json['subtypeQuantities'] = subtypeQuantities;
    }
    return json;
  }

  // Copy with method for immutable updates
  Product copyWith({
    String? name,
    int? price,
    int? quantity,
    bool? isAvailable,
    String? type,
    List<String>? subtypes,
    Map<String, int>? subtypeQuantities,
  }) {
    return Product(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isAvailable: isAvailable ?? this.isAvailable,
      type: type ?? this.type,
      subtypes: subtypes ?? this.subtypes,
      subtypeQuantities: subtypeQuantities ?? Map.from(this.subtypeQuantities),
    );
  }
}
