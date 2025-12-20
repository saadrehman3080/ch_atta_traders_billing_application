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

  // Dummy data for testing (will be replaced with Firebase data)
  static List<Product> getDummyProducts() {
    return [
      // Frequently Used Products
      Product(name: 'Pepsi 1500ml', price: 990),
      Product(name: 'Pepsi 250ml RB', price: 920),
      Product(name: 'Pepsi NR 300ml', price: 740),
      Product(name: 'Sting 240ml RB', price: 1200),
      Product(name: 'Shezan RB', price: 910),
      Product(name: 'Sting NR 300ml', price: 880),
      Product(name: 'Slice 200ml', price: 1020),
      Product(name: 'Aquafina 1500ml', price: 450),

      // Carbonated Drinks — 300ml (NR)
      Product(name: 'Bigapple NR 300ml', price: 600),
      Product(name: 'Revive NR 300ml', price: 500),
      Product(name: 'Master Cola NR 300ml', price: 550),

      // Juices
      Product(name: 'Slice 1000ml', price: 0),
      Product(name: 'Tops Tangy 250ml', price: 680),
      Product(name: 'Shezan 250ml', price: 890),

      Product(name: 'Big Apple 1500ml', price: 850),
      Product(name: 'Coke 1500ml', price: 1020),
      Product(name: 'Master Cola 1500ml', price: 700),

      // Cans
      Product(name: 'Pepsi Can 330ml', price: 1160),
      Product(name: 'Sting Can 330ml', price: 1230),

      // Carbonated Drinks — 2250ml
      Product(name: 'Pepsi 2250ml', price: 920),
      Product(name: 'Master Cola 2250ml', price: 0),

      // Carbonated Drinks — 1000ml
      Product(name: 'Pepsi 1000ml', price: 870),

      // 500ml Bottles
      Product(name: 'Pepsi 500ml', price: 1100),
      Product(name: 'Sting 500ml', price: 1260),
      Product(name: 'Gatorade 500ml', price: 990),

      // Water
      Product(name: 'Aquafina 500ml', price: 500),
      Product(name: 'Aquafina 19L', price: 400),
      Product(name: 'Murree Sparklet 1500ml', price: 440),
      Product(name: 'Murree Sparklet 500ml', price: 440),
      Product(name: 'Nestlé 1500ml', price: 490),
      Product(name: 'Master Water', price: 0),
    ];
  }
}
