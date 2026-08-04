/// Aggregated dashboard data for display on the dashboard.
/// Data is stored and updated incrementally in Firebase.
class DashboardData {
  final int totalCollection;
  final int totalItemsSold;
  final int totalMtRemaining;
  final int totalCredit;
  final int totalDiscount;
  final int customersServed;

  /// Cash collected from previous day credit bills (nullable - null means no previous day data)
  final int? previousDayCash;

  /// MT (crates) collected from previous day credit bills (nullable - null means no previous day data)
  final int? previousDayMt;

  DashboardData({
    required this.totalCollection,
    required this.totalItemsSold,
    required this.totalMtRemaining,
    required this.totalCredit,
    required this.totalDiscount,
    required this.customersServed,
    this.previousDayCash,
    this.previousDayMt,
  });

  /// Check if there's any previous day data to show
  bool get hasPreviousDayData =>
      (previousDayCash != null && previousDayCash! > 0) ||
      (previousDayMt != null && previousDayMt! > 0);

  /// Create from JSON (Firebase document)
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalCollection: json['totalCollection'] as int? ?? 0,
      totalItemsSold: json['totalItemsSold'] as int? ?? 0,
      totalMtRemaining: json['totalMtRemaining'] as int? ?? 0,
      totalCredit: json['totalCredit'] as int? ?? 0,
      totalDiscount: json['totalDiscount'] as int? ?? 0,
      customersServed: json['customersServed'] as int? ?? 0,
      previousDayCash: json['previousDayCash'] as int?,
      previousDayMt: json['previousDayMt'] as int?,
    );
  }
}
