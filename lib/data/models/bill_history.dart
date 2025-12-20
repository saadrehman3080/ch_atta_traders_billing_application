import 'package:ch_atta_traders_billing_application/data/models/product.dart';

class BillHistory {
  final String billId;
  final String customerName;
  final DateTime date;
  final List<Product> products;

  BillHistory({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.products,
  });

  // Factory constructor to create BillHistory from JSON (Firebase)
  factory BillHistory.fromJson(Map<String, dynamic> json) {
    return BillHistory(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      date: DateTime.parse(json['date'] as String),
      products: (json['products'] as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // Convert BillHistory to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'products': products.map((product) => product.toJson()).toList(),
    };
  }

  // Copy with method for immutable updates
  BillHistory copyWith({
    String? billId,
    String? customerName,
    DateTime? date,
    List<Product>? products,
  }) {
    return BillHistory(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      products: products ?? this.products,
    );
  }

  // Helper method to get formatted date
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Helper method to get formatted time
  String get formattedTime {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // Dummy data for testing (will be replaced with Firebase data)
  static List<BillHistory> getDummyBillHistory() {
    return [
      BillHistory(
        billId: 'BILL001',
        customerName: 'Ahmed Khan',
        date: DateTime(2025, 12, 20, 10, 30),
        products: [
          Product(name: 'Pepsi 1500ml', quantity: 2, price: 990),
          Product(name: 'Sting 240ml RB', quantity: 1, price: 1200),
          Product(name: 'Aquafina 1500ml', quantity: 3, price: 450),
          Product(name: 'Coke 1500ml', quantity: 3, price: 1020),
          Product(name: 'Pepsi Can 330ml', quantity: 2, price: 1160),
          Product(name: 'Pepsi 2250ml', quantity: 5, price: 920),
          Product(name: 'Master Cola 1500ml', quantity: 4, price: 700),
          Product(name: 'Slice 200ml', quantity: 2, price: 1020),
          Product(name: 'Big Apple 1500ml', quantity: 6, price: 850),
          Product(name: 'Revive NR 300ml', quantity: 5, price: 500),
          Product(name: 'Nestlé 1500ml', quantity: 3, price: 490),
        ],
      ),
      BillHistory(
        billId: 'BILL002',
        customerName: 'Naiz Bakers',
        date: DateTime(2025, 12, 20, 11, 15),
        products: [
          Product(name: 'Coke 1500ml', quantity: 3, price: 1020),
          Product(name: 'Pepsi Can 330ml', quantity: 2, price: 1160),
        ],
      ),
      BillHistory(
        billId: 'BILL003',
        customerName: 'Babu Ismail',
        date: DateTime(2025, 12, 19, 14, 45),
        products: [
          Product(name: 'Pepsi 2250ml', quantity: 5, price: 920),
          Product(name: 'Master Cola 1500ml', quantity: 4, price: 700),
          Product(name: 'Slice 200ml', quantity: 2, price: 1020),
        ],
      ),
      BillHistory(
        billId: 'BILL004',
        customerName: 'Ayesha Malik',
        date: DateTime(2025, 12, 19, 16, 20),
        products: [
          Product(name: 'Gatorade 500ml', quantity: 4, price: 990),
          Product(name: 'Sting 500ml', quantity: 2, price: 1260),
        ],
      ),
      BillHistory(
        billId: 'BILL005',
        customerName: 'Muhammad Usman',
        date: DateTime(2025, 12, 18, 9, 10),
        products: [
          Product(name: 'Big Apple 1500ml', quantity: 6, price: 850),
          Product(name: 'Revive NR 300ml', quantity: 5, price: 500),
          Product(name: 'Nestlé 1500ml', quantity: 3, price: 490),
        ],
      ),
      BillHistory(
        billId: 'BILL006',
        customerName: 'Sara Ahmed',
        date: DateTime(2025, 12, 18, 13, 50),
        products: [
          Product(name: 'Pepsi 1000ml', quantity: 3, price: 870),
          Product(name: 'Shezan 250ml', quantity: 4, price: 890),
        ],
      ),
      BillHistory(
        billId: 'BILL007',
        customerName: 'Ali Hassan',
        date: DateTime(2025, 12, 17, 15, 30),
        products: [
          Product(name: 'Pepsi NR 300ml', quantity: 8, price: 740),
          Product(name: 'Tops Tangy 250ml', quantity: 3, price: 680),
          Product(name: 'Aquafina 500ml', quantity: 6, price: 500),
        ],
      ),
      BillHistory(
        billId: 'BILL008',
        customerName: 'Zainab Sheikh',
        date: DateTime(2025, 12, 17, 17, 15),
        products: [
          Product(name: 'Sting Can 330ml', quantity: 3, price: 1230),
          Product(name: 'Pepsi 500ml', quantity: 2, price: 1100),
        ],
      ),
    ];
  }
}
