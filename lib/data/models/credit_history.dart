import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single partial payment entry with date and amount
class PartialPayment {
  final DateTime date;
  final int amount;

  PartialPayment({required this.date, required this.amount});

  factory PartialPayment.fromJson(Map<String, dynamic> json) {
    return PartialPayment(
      date: DateTime.parse(json['date'] as String),
      amount: json['amount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'amount': amount};
  }
}

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
  final bool isReceiptGenerated;
  @override
  final BillType billType;

  final int cratesDue;
  final bool isPaid;
  final int amountDue;
  final bool isRecordUpdated;
  final List<PartialPayment> partialPayments;

  CreditHistory({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.products,
    this.discount = 0,
    this.isReceiptGenerated = false,
    this.isPaid = false,
    this.amountDue = 0,
    this.cratesDue = 0,
    this.isRecordUpdated = false,
    this.billType = BillType.credit,
    this.partialPayments = const [],
  });

  // Factory constructor to create CreditHistory from JSON (Firebase)
  factory CreditHistory.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return CreditHistory(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      date: parseDate(json['date']),
      products: (json['products'] as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      discount: json['discount'] as int? ?? 0,
      isReceiptGenerated: json['isReceiptGenerated'] as bool? ?? false,
      isPaid: json['isPaid'] as bool? ?? true,
      amountDue: json['amountDue'] as int? ?? 0,
      cratesDue: json['cratesDue'] as int? ?? 0,
      isRecordUpdated: json['isRecordUpdated'] as bool? ?? false,
      billType: BillType.fromJson(json['billType'] as String?),
      partialPayments: json['partialPayments'] != null
          ? (json['partialPayments'] as List<dynamic>)
                .map(
                  (item) =>
                      PartialPayment.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
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
      'isReceiptGenerated': isReceiptGenerated,
      'isPaid': isPaid,
      'amountDue': amountDue,
      'isRecordUpdated': isRecordUpdated,
      'cratesDue': cratesDue,
      'billType': billType.toJson(),
      'partialPayments': partialPayments.map((p) => p.toJson()).toList(),
    };
  }

  // Copy with method for immutable updates
  CreditHistory copyWith({
    String? billId,
    String? customerName,
    DateTime? date,
    List<Product>? products,
    int? discount,
    bool? isReceiptGenerated,
    bool? isPaid,
    int? amountDue,
    int? cratesDue,
    bool? isRecordUpdated,
    BillType? billType,
    List<PartialPayment>? partialPayments,
  }) {
    return CreditHistory(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      products: products ?? this.products,
      discount: discount ?? this.discount,
      isReceiptGenerated: isReceiptGenerated ?? this.isReceiptGenerated,
      isPaid: isPaid ?? this.isPaid,
      amountDue: amountDue ?? this.amountDue,
      cratesDue: cratesDue ?? this.cratesDue,
      isRecordUpdated: isRecordUpdated ?? this.isRecordUpdated,
      billType: billType ?? this.billType,
      partialPayments: partialPayments ?? this.partialPayments,
    );
  }

  /// Total amount received via partial payments
  int get totalPartialPaymentAmount {
    return partialPayments.fold(0, (sum, p) => sum + p.amount);
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
