import 'package:ch_atta_traders_billing_application/data/models/product.dart';

/// Enum representing the type of bill payment
enum BillType {
  cash,
  credit;

  /// Convert BillType to string for Firebase storage
  String toJson() => name;

  /// Create BillType from string stored in Firebase
  static BillType fromJson(String? value) {
    if (value == 'credit') return BillType.credit;
    return BillType.cash; // Default to cash
  }
}

/// Base interface for all bill-related entities (Sales and Credit transactions)
abstract class BillBase {
  String get billId;
  String get customerName;
  DateTime get date;
  List<Product> get products;
  int get discount;
  bool get isReceiptGenerated;

  /// The type of bill - cash or credit
  BillType get billType;

  // Helper methods - must be implemented by subclasses
  String get formattedDate;
  String get formattedTime;

  // Firebase methods
  Map<String, dynamic> toJson();
}
