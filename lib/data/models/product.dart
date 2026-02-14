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

  Product({
    required this.name,
    required this.price,
    this.quantity = 0,
    this.isAvailable = true,
    this.type = 'others',
  });

  // Factory constructor to create Product from JSON (Firebase)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      type: json['type'] as String? ?? 'others',
    );
  }

  // Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'price': price, 'quantity': quantity, 'type': type};
  }

  // Copy with method for immutable updates
  Product copyWith({
    String? name,
    int? price,
    int? quantity,
    bool? isAvailable,
    String? type,
  }) {
    return Product(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isAvailable: isAvailable ?? this.isAvailable,
      type: type ?? this.type,
    );
  }
}
