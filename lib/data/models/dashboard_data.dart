import 'package:ch_atta_traders_billing_application/data/models/product.dart';

/// Represents a single bill's summary data for dashboard calculations
class BillSummary {
  final String billId;
  final int totalAmount;
  final int itemsSold;
  final int mtRemaining;
  final int creditAmount;
  final int discount;
  final DateTime date;

  BillSummary({
    required this.billId,
    required this.totalAmount,
    required this.itemsSold,
    required this.mtRemaining,
    required this.creditAmount,
    required this.discount,
    required this.date,
  });

  /// Factory to create BillSummary from a list of products
  factory BillSummary.fromProducts({
    required String billId,
    required List<Product> products,
    required int discount,
    required bool isCredit,
    required DateTime date,
  }) {
    // Calculate total amount
    final totalAmount = products.fold<int>(
      0,
      (sum, product) => sum + (product.price * product.quantity),
    );

    // Calculate items sold (total quantity)
    final itemsSold = products.fold<int>(
      0,
      (sum, product) => sum + product.quantity,
    );

    // Calculate MT remaining (RB products only)
    final mtRemaining = products
        .where((product) => product.name.toUpperCase().endsWith('RB'))
        .fold<int>(0, (sum, product) => sum + product.quantity);

    // Credit amount is total amount if isCredit, 0 otherwise
    final creditAmount = isCredit ? totalAmount - discount : 0;

    return BillSummary(
      billId: billId,
      totalAmount: totalAmount - discount,
      itemsSold: itemsSold,
      mtRemaining: mtRemaining,
      creditAmount: creditAmount,
      discount: discount,
      date: date,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'totalAmount': totalAmount,
      'itemsSold': itemsSold,
      'mtRemaining': mtRemaining,
      'creditAmount': creditAmount,
      'discount': discount,
      'date': date.toIso8601String(),
    };
  }

  // Create from JSON
  factory BillSummary.fromJson(Map<String, dynamic> json) {
    return BillSummary(
      billId: json['billId'] as String,
      totalAmount: json['totalAmount'] as int,
      itemsSold: json['itemsSold'] as int,
      mtRemaining: json['mtRemaining'] as int,
      creditAmount: json['creditAmount'] as int,
      discount: json['discount'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

/// Aggregated dashboard data calculated from multiple bills
class DashboardData {
  final int totalCollection;
  final int totalItemsSold;
  final int totalMtRemaining;
  final int totalCredit;
  final int totalDiscount;
  final int customersServed;

  DashboardData({
    required this.totalCollection,
    required this.totalItemsSold,
    required this.totalMtRemaining,
    required this.totalCredit,
    required this.totalDiscount,
    required this.customersServed,
  });

  /// Calculate dashboard data from a list of bill summaries
  factory DashboardData.fromBills(List<BillSummary> bills) {
    if (bills.isEmpty) {
      return DashboardData(
        totalCollection: 0,
        totalItemsSold: 0,
        totalMtRemaining: 0,
        totalCredit: 0,
        totalDiscount: 0,
        customersServed: 0,
      );
    }

    return DashboardData(
      totalCollection: bills.fold<int>(
        0,
        (sum, bill) => sum + bill.totalAmount,
      ),
      totalItemsSold: bills.fold<int>(0, (sum, bill) => sum + bill.itemsSold),
      totalMtRemaining: bills.fold<int>(
        0,
        (sum, bill) => sum + bill.mtRemaining,
      ),
      totalCredit: bills.fold<int>(0, (sum, bill) => sum + bill.creditAmount),
      totalDiscount: bills.fold<int>(0, (sum, bill) => sum + bill.discount),
      customersServed: bills.length,
    );
  }

  /// Calculate dashboard data from today's bills (already filtered by date from database)
  factory DashboardData.forToday(List<BillSummary> bills) {
    return DashboardData.fromBills(bills);
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalCollection': totalCollection,
      'totalItemsSold': totalItemsSold,
      'totalMtRemaining': totalMtRemaining,
      'totalCredit': totalCredit,
      'totalDiscount': totalDiscount,
      'customersServed': customersServed,
    };
  }

  // Create from JSON
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalCollection: json['totalCollection'] as int,
      totalItemsSold: json['totalItemsSold'] as int,
      totalMtRemaining: json['totalMtRemaining'] as int,
      totalCredit: json['totalCredit'] as int,
      totalDiscount: json['totalDiscount'] as int,
      customersServed: json['customersServed'] as int,
    );
  }

  // Dummy data for testing
  static DashboardData getDummyData() {
    return DashboardData(
      totalCollection: 76830,
      totalItemsSold: 199,
      totalMtRemaining: 7,
      totalCredit: 13000,
      totalDiscount: 320,
      customersServed: 28,
    );
  }
}
