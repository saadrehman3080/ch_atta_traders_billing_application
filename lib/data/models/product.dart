class Product {
  final String name;
  final int price;
  int quantity;

  Product({required this.name, required this.price, this.quantity = 0});

  // Factory constructor to create Product from JSON (Firebase)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int? ?? 0,
    );
  }

  // Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'price': price, 'quantity': quantity};
  }

  // Copy with method for immutable updates
  Product copyWith({String? name, int? price, int? quantity}) {
    return Product(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }
}
