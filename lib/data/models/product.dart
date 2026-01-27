class Product {
  final String name;
  final int price;
  int quantity;
  final bool isAvailable;

  Product({
    required this.name,
    required this.price,
    this.quantity = 0,
    this.isAvailable = true,
  });

  // Factory constructor to create Product from JSON (Firebase)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  // Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      // 'isAvailable': isAvailable, // Excluded from JSON it's not needed in Firebase
    };
  }

  // Copy with method for immutable updates
  Product copyWith({
    String? name,
    int? price,
    int? quantity,
    bool? isAvailable,
  }) {
    return Product(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
