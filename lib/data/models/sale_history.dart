import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  @override
  final bool isReceiptGenerated;
  @override
  final BillType billType;
  final double? latitude;
  final double? longitude;

  SaleHistory({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.products,
    this.discount = 0,
    this.isReceiptGenerated = true,
    this.billType = BillType.cash,
    this.latitude,
    this.longitude,
  });

  // Factory constructor to create SaleHistory from JSON (Firebase)
  factory SaleHistory.fromJson(Map<String, dynamic> json) {
    // Handle both Firestore Timestamp and ISO8601 String
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return DateTime.now();
      }
    }

    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return SaleHistory(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      date: parseDate(json['date']),
      products: (json['products'] as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      discount: json['discount'] as int? ?? 0,
      isReceiptGenerated: json['isReceiptGenerated'] as bool? ?? true,
      billType: BillType.fromJson(json['billType'] as String?),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
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
      'isReceiptGenerated': isReceiptGenerated,
      'billType': billType.toJson(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Copy with method for immutable updates
  SaleHistory copyWith({
    String? billId,
    String? customerName,
    DateTime? date,
    List<Product>? products,
    int? discount,
    bool? isReceiptGenerated,
    BillType? billType,
    double? latitude,
    double? longitude,
  }) {
    return SaleHistory(
      billId: billId ?? this.billId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      products: products ?? this.products,
      discount: discount ?? this.discount,
      isReceiptGenerated: isReceiptGenerated ?? this.isReceiptGenerated,
      billType: billType ?? this.billType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
}
