import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';

class SaleHistory implements BillBase {
  @override
  final String billId;
  @override
  final String customerName;
  @override
  final DateTime date;
  @override
  final List<Product> products;
  @override
  final int discount;

  SaleHistory({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.products,
    this.discount = 0,
  });

  // Factory constructor to create SaleHistory from JSON (Firebase)
  factory SaleHistory.fromJson(Map<String, dynamic> json) {
    return SaleHistory(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      date: DateTime.parse(json['date'] as String),
      products: (json['products'] as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      discount: json['discount'] as int? ?? 0,
    );
  }

  // Convert SaleHistory to JSON for Firebase
  @override
  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'products': products.map((product) => product.toJson()).toList(),
      'discount': discount,
    };
  }

  // Copy with method for immutable updates
  SaleHistory copyWith({
    String? billId,
    String? customerName,
    DateTime? date,
    List<Product>? products,
    int? discount,
  }) {
    return SaleHistory(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      products: products ?? this.products,
      discount: discount ?? this.discount,
    );
  }

  // Helper methods
  @override
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  String get formattedTime {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // Dummy data for testing (will be replaced with Firebase data)
  static List<SaleHistory> getDummySaleHistory() {
    return [
      SaleHistory(
        billId: 'SALE001',
        customerName: 'Ahmed Khan',
        date: DateTime(2025, 12, 20, 10, 30),
        products: [
          Product(name: 'Pepsi 1500ml', quantity: 2, price: 990),
          Product(name: 'Sting 240ml RB', quantity: 1, price: 1200),
          Product(name: 'Aquafina 1500ml', quantity: 3, price: 450),
        ],
        discount: 150,
      ),
      SaleHistory(
        billId: 'SALE002',
        customerName: 'Naiz Bakers',
        date: DateTime(2025, 12, 20, 11, 15),
        products: [
          Product(name: 'Coke 1500ml', quantity: 3, price: 1020),
          Product(name: 'Pepsi Can 330ml', quantity: 2, price: 1160),
        ],
        discount: 100,
      ),
      SaleHistory(
        billId: 'SALE003',
        customerName: 'Babu Ismail',
        date: DateTime(2025, 12, 19, 14, 45),
        products: [
          Product(name: 'Pepsi 2250ml', quantity: 5, price: 920),
          Product(name: 'Master Cola 1500ml', quantity: 4, price: 700),
        ],
      ),
      SaleHistory(
        billId: 'SALE004',
        customerName: 'Ayesha Malik',
        date: DateTime(2025, 12, 19, 16, 20),
        products: [
          Product(name: 'Gatorade 500ml', quantity: 4, price: 990),
          Product(name: 'Sting 500ml', quantity: 2, price: 1260),
        ],
      ),
    ];
  }
}
