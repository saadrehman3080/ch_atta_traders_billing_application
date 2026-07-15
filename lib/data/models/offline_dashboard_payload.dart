/// Per-bill dashboard delta payload queued for offline-first sync.
class OfflineDashboardPayload {
  final String billId;
  final String salesmanIdentifier;
  final DateTime date;
  final int totalCollectionDelta;
  final int totalItemsSoldDelta;
  final int totalMtRemainingDelta;
  final int totalCreditDelta;
  final int totalDiscountDelta;
  final int customersServedDelta;
  final int previousDayCashDelta;
  final int previousDayMtDelta;
  final DateTime createdAt;
  final int schemaVersion;

  const OfflineDashboardPayload({
    required this.billId,
    required this.salesmanIdentifier,
    required this.date,
    required this.totalCollectionDelta,
    required this.totalItemsSoldDelta,
    required this.totalMtRemainingDelta,
    required this.totalCreditDelta,
    required this.totalDiscountDelta,
    required this.customersServedDelta,
    this.previousDayCashDelta = 0,
    this.previousDayMtDelta = 0,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'salesmanIdentifier': salesmanIdentifier,
      'date': date.toIso8601String(),
      'totalCollectionDelta': totalCollectionDelta,
      'totalItemsSoldDelta': totalItemsSoldDelta,
      'totalMtRemainingDelta': totalMtRemainingDelta,
      'totalCreditDelta': totalCreditDelta,
      'totalDiscountDelta': totalDiscountDelta,
      'customersServedDelta': customersServedDelta,
      'previousDayCashDelta': previousDayCashDelta,
      'previousDayMtDelta': previousDayMtDelta,
      'createdAt': createdAt.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  factory OfflineDashboardPayload.fromJson(Map<String, dynamic> json) {
    return OfflineDashboardPayload(
      billId: json['billId'] as String,
      salesmanIdentifier: json['salesmanIdentifier'] as String,
      date: DateTime.parse(json['date'] as String),
      totalCollectionDelta:
          (json['totalCollectionDelta'] as num?)?.toInt() ?? 0,
      totalItemsSoldDelta: (json['totalItemsSoldDelta'] as num?)?.toInt() ?? 0,
      totalMtRemainingDelta:
          (json['totalMtRemainingDelta'] as num?)?.toInt() ?? 0,
      totalCreditDelta: (json['totalCreditDelta'] as num?)?.toInt() ?? 0,
      totalDiscountDelta: (json['totalDiscountDelta'] as num?)?.toInt() ?? 0,
      customersServedDelta:
          (json['customersServedDelta'] as num?)?.toInt() ?? 0,
      previousDayCashDelta:
          (json['previousDayCashDelta'] as num?)?.toInt() ?? 0,
      previousDayMtDelta: (json['previousDayMtDelta'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
