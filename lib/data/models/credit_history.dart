import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';

class CreditHistory implements BillBase {
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

  final int cratesDue;
  final bool isPaid;
  final int amountDue;

  CreditHistory({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.products,
    this.discount = 0,
    this.isPaid = false,
    this.amountDue = 0,
    this.cratesDue = 0,
  });

  // Factory constructor to create CreditHistory from JSON (Firebase)
  factory CreditHistory.fromJson(Map<String, dynamic> json) {
    return CreditHistory(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      date: DateTime.parse(json['date'] as String),
      products: (json['products'] as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      discount: json['discount'] as int? ?? 0,
      isPaid: json['isPaid'] as bool? ?? true,
      amountDue: json['amountDue'] as int? ?? 0,
      cratesDue: json['cratesDue'] as int? ?? 0,
    );
  }

  // Convert CreditHistory to JSON for Firebase
  @override
  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'products': products.map((product) => product.toJson()).toList(),
      'discount': discount,
      'isPaid': isPaid,
      'amountDue': amountDue,
      'cratesDue': cratesDue,
    };
  }

  // Copy with method for immutable updates
  CreditHistory copyWith({
    String? billId,
    String? customerName,
    DateTime? date,
    List<Product>? products,
    int? discount,
    bool? isPaid,
    int? amountDue,
    int? cratesDue,
  }) {
    return CreditHistory(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      products: products ?? this.products,
      discount: discount ?? this.discount,
      isPaid: isPaid ?? this.isPaid,
      amountDue: amountDue ?? this.amountDue,
      cratesDue: cratesDue ?? this.cratesDue,
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
  static List<CreditHistory> getDummyCreditHistory() {
    return [
      CreditHistory(
        billId: 'BILL001',
        customerName: 'Ahmed Khan',
        date: DateTime(2025, 12, 20, 10, 30),
        products: [
          Product(name: 'Pepsi 1500ml', quantity: 2, price: 990),
          Product(name: 'Sting 240ml RB', quantity: 10, price: 1200),
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
        discount: 150,
        isPaid: true,
        amountDue: 0,
        cratesDue: 9, // 10 RB product (Sting 240ml RB x10) - some returned
      ),
      CreditHistory(
        billId: 'BILL002',
        customerName: 'Naiz Bakers',
        date: DateTime(2025, 12, 20, 11, 15),
        products: [
          Product(name: 'Coke 1500ml', quantity: 3, price: 1020),
          Product(name: 'Pepsi Can 330ml', quantity: 2, price: 1160),
          Product(name: 'Pepsi 250ml RB', quantity: 13, price: 920),
        ],
        discount: 100,
        isPaid: true,
        amountDue: 0,
        cratesDue: 12, // 12 RB products - 1 returned
      ),
      CreditHistory(
        billId: 'BILL003',
        customerName: 'Babu Ismail',
        date: DateTime(2025, 12, 19, 14, 45),
        discount: 100,
        products: [
          Product(name: 'Pepsi 2250ml', quantity: 5, price: 920),
          Product(name: 'Master Cola 1500ml', quantity: 4, price: 700),
          Product(name: 'Slice 200ml', quantity: 2, price: 1020),
          Product(name: 'Shezan 250ml RB', quantity: 5, price: 910),
        ],
        isPaid: false,
        amountDue: 7640, // (5*920 + 4*700 + 2*1020 + 5*910) - 100 = 7640
        cratesDue: 5, // 5 RB products
      ),
      CreditHistory(
        billId: 'BILL004',
        customerName: 'Ayesha Malik',
        date: DateTime(2025, 12, 19, 16, 20),
        products: [
          Product(name: 'Gatorade 500ml', quantity: 4, price: 990),
          Product(name: 'Sting 500ml', quantity: 2, price: 1260),
        ],
        isPaid: false,
        amountDue: 6480, // 4*990 + 2*1260 = 6480
        cratesDue: 0, // No RB products
      ),
      CreditHistory(
        billId: 'BILL005',
        customerName: 'Muhammad Usman',
        date: DateTime(2025, 12, 18, 9, 10),
        products: [
          Product(name: 'Big Apple 1500ml', quantity: 6, price: 850),
          Product(name: 'Revive NR 300ml', quantity: 5, price: 500),
          Product(name: 'Nestlé 1500ml', quantity: 3, price: 490),
        ],
        isPaid: false,
        amountDue: 9170, // 6*850 + 5*500 + 3*490 = 9170
        cratesDue: 0, // No RB products
      ),
      CreditHistory(
        billId: 'BILL006',
        customerName: 'Sara Ahmed',
        date: DateTime(2025, 12, 18, 13, 50),
        products: [
          Product(name: 'Pepsi 1000ml', quantity: 3, price: 870),
          Product(name: 'Shezan 250ml RB', quantity: 4, price: 890),
        ],
        isPaid: false,
        amountDue: 6170, // 3*870 + 4*890 = 6170
        cratesDue: 4, // 4 RB products
      ),
      CreditHistory(
        billId: 'BILL007',
        customerName: 'Ali Hassan',
        date: DateTime(2025, 12, 17, 15, 30),
        products: [
          Product(name: 'Pepsi NR 300ml', quantity: 8, price: 740),
          Product(name: 'Tops Tangy 250ml', quantity: 3, price: 680),
          Product(name: 'Aquafina 500ml', quantity: 6, price: 500),
        ],
        isPaid: false,
        amountDue: 10960, // 8*740 + 3*680 + 6*500 = 10960
        cratesDue: 0, // No RB products
      ),
      CreditHistory(
        billId: 'BILL008',
        customerName: 'Zainab Sheikh',
        date: DateTime(2025, 12, 17, 17, 15),
        products: [
          Product(name: 'Sting Can 330ml', quantity: 3, price: 1230),
          Product(name: 'Pepsi 500ml', quantity: 2, price: 1100),
        ],
        isPaid: false,
        amountDue: 5890, // 3*1230 + 2*1100 = 5890
        cratesDue: 0, // No RB products
      ),
    ];
  }
}
