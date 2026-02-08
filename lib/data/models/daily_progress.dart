import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a product sold in a daily sales record.
class DailyProgressProduct {
  final String name;
  final int price;
  final int returned;
  final int sold;
  final int takenOut;
  final int totalAmount;

  DailyProgressProduct({
    required this.name,
    required this.price,
    required this.returned,
    required this.sold,
    required this.takenOut,
    required this.totalAmount,
  });

  factory DailyProgressProduct.fromJson(Map<String, dynamic> json) {
    return DailyProgressProduct(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      returned: (json['returned'] as num?)?.toInt() ?? 0,
      sold: (json['sold'] as num?)?.toInt() ?? 0,
      takenOut: (json['takenOut'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents the empty crates data for a daily sales record.
class EmptyCrates {
  final int excess;
  final int issued;
  final int rbProductsReturned;
  final int returned;
  final int short;

  EmptyCrates({
    required this.excess,
    required this.issued,
    required this.rbProductsReturned,
    required this.returned,
    required this.short,
  });

  factory EmptyCrates.fromJson(Map<String, dynamic> json) {
    return EmptyCrates(
      excess: (json['excess'] as num?)?.toInt() ?? 0,
      issued: (json['issued'] as num?)?.toInt() ?? 0,
      rbProductsReturned: (json['rbProductsReturned'] as num?)?.toInt() ?? 0,
      returned: (json['returned'] as num?)?.toInt() ?? 0,
      short: (json['short'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents the expenses data for a daily sales record.
class DailyExpenses {
  final int discount;
  final int food;
  final int other;
  final String otherDescription;
  final int petrol;
  final int total;

  DailyExpenses({
    required this.discount,
    required this.food,
    required this.other,
    required this.otherDescription,
    required this.petrol,
    required this.total,
  });

  factory DailyExpenses.fromJson(Map<String, dynamic> json) {
    return DailyExpenses(
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      food: (json['food'] as num?)?.toInt() ?? 0,
      other: (json['other'] as num?)?.toInt() ?? 0,
      otherDescription: json['otherDescription'] as String? ?? '',
      petrol: (json['petrol'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents a complete daily sales progress record for a salesman.
/// Firestore path: /salesmen/{salesmanDocId}/daily_sales/{date}
class DailyProgress {
  final int cashReceived;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final String date;
  final EmptyCrates emptyCrates;
  final DailyExpenses expenses;
  final int finalAmount;
  final List<DailyProgressProduct> products;
  final String salesmanId;
  final String salesmanName;
  final String status;
  final int totalExpenses;
  final int totalSalesAmount;

  DailyProgress({
    required this.cashReceived,
    this.completedAt,
    this.createdAt,
    required this.date,
    required this.emptyCrates,
    required this.expenses,
    required this.finalAmount,
    required this.products,
    required this.salesmanId,
    required this.salesmanName,
    required this.status,
    required this.totalExpenses,
    required this.totalSalesAmount,
  });

  /// Total items sold across all products
  int get totalItemsSold => products.fold<int>(0, (sum, p) => sum + p.sold);

  /// Total items taken out across all products
  int get totalItemsTakenOut =>
      products.fold<int>(0, (sum, p) => sum + p.takenOut);

  /// Total items returned across all products
  int get totalItemsReturned =>
      products.fold<int>(0, (sum, p) => sum + p.returned);

  /// Whether the daily sale is completed
  bool get isCompleted => status == 'completed';

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    // Parse completedAt
    DateTime? completedAt;
    if (json['completedAt'] != null) {
      if (json['completedAt'] is Timestamp) {
        completedAt = (json['completedAt'] as Timestamp).toDate();
      }
    }

    // Parse createdAt
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAt = (json['createdAt'] as Timestamp).toDate();
      }
    }

    // Parse products
    final productsList = <DailyProgressProduct>[];
    if (json['products'] != null && json['products'] is List) {
      for (final item in json['products'] as List) {
        if (item is Map<String, dynamic>) {
          productsList.add(DailyProgressProduct.fromJson(item));
        }
      }
    }

    // Parse emptyCrates
    final emptyCrates =
        json['emptyCrates'] != null &&
            json['emptyCrates'] is Map<String, dynamic>
        ? EmptyCrates.fromJson(json['emptyCrates'] as Map<String, dynamic>)
        : EmptyCrates(
            excess: 0,
            issued: 0,
            rbProductsReturned: 0,
            returned: 0,
            short: 0,
          );

    // Parse expenses
    final expenses =
        json['expenses'] != null && json['expenses'] is Map<String, dynamic>
        ? DailyExpenses.fromJson(json['expenses'] as Map<String, dynamic>)
        : DailyExpenses(
            discount: 0,
            food: 0,
            other: 0,
            otherDescription: '',
            petrol: 0,
            total: 0,
          );

    return DailyProgress(
      cashReceived: (json['cashReceived'] as num?)?.toInt() ?? 0,
      completedAt: completedAt,
      createdAt: createdAt,
      date: json['date'] as String? ?? '',
      emptyCrates: emptyCrates,
      expenses: expenses,
      finalAmount: (json['finalAmount'] as num?)?.toInt() ?? 0,
      products: productsList,
      salesmanId: json['salesmanId'] as String? ?? '',
      salesmanName: json['salesmanName'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalExpenses: (json['totalExpenses'] as num?)?.toInt() ?? 0,
      totalSalesAmount: (json['totalSalesAmount'] as num?)?.toInt() ?? 0,
    );
  }
}
