import 'package:ch_atta_traders_billing_application/data/models/product.dart';

/// Base interface for all bill-related entities (Sales and Credit transactions)
abstract class BillBase {
  String get billId;
  String get customerName;
  DateTime get date;
  List<Product> get products;
  int get discount;

  // Helper methods - must be implemented by subclasses
  String get formattedDate;
  String get formattedTime;

  // Firebase methods
  Map<String, dynamic> toJson();
}
