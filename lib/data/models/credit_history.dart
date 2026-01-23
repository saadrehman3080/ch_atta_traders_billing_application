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
  @override
  final BillType billType;

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
    this.billType = BillType.credit,
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
      billType: BillType.fromJson(json['billType'] as String?),
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
      'billType': billType.toJson(),
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
    BillType? billType,
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
      billType: billType ?? this.billType,
    );
  }

  // Helper methods
  @override
  String get formattedDate {
    return '${date.day}-${date.month}-${date.year}';
  }

  @override
  String get formattedTime {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
