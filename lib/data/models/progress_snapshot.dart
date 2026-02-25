import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores cumulative totals for all daily progress records up to [snapshotDate].
///
/// Instead of fetching the entire history on every load, the app stores a
/// running snapshot that absorbs older records. Only records *after* the
/// snapshot date need to be fetched from Firestore, dramatically reducing
/// read costs and bandwidth as the data grows over months and years.
///
/// Firestore path: /salesmen/{salesmanDocId}/progress_snapshots/latest
class ProgressSnapshot {
  /// All records up to and including this date are absorbed.
  /// Format: YYYY-MM-DD (sorts lexicographically).
  final String snapshotDate;

  /// Cumulative net MT balance (excess − short) for absorbed records.
  final int totalNetMt;

  /// Cumulative net cash balance (sum of finalAmount) for absorbed records.
  final int totalNetCash;

  /// Cumulative cash received for absorbed records.
  final int totalCashReceived;

  /// Cumulative total sales amount for absorbed records.
  final int totalSalesAmount;

  /// Number of records absorbed into this snapshot.
  final int totalRecordCount;

  /// When the snapshot was last updated (server timestamp).
  final DateTime? updatedAt;

  ProgressSnapshot({
    required this.snapshotDate,
    required this.totalNetMt,
    required this.totalNetCash,
    required this.totalCashReceived,
    required this.totalSalesAmount,
    required this.totalRecordCount,
    this.updatedAt,
  });

  /// An empty sentinel used when no snapshot exists yet.
  factory ProgressSnapshot.empty() {
    return ProgressSnapshot(
      snapshotDate: '',
      totalNetMt: 0,
      totalNetCash: 0,
      totalCashReceived: 0,
      totalSalesAmount: 0,
      totalRecordCount: 0,
    );
  }

  bool get isEmpty => snapshotDate.isEmpty;

  factory ProgressSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? updatedAt;
    if (json['updatedAt'] is Timestamp) {
      updatedAt = (json['updatedAt'] as Timestamp).toDate();
    }

    return ProgressSnapshot(
      snapshotDate: json['snapshotDate'] as String? ?? '',
      totalNetMt: (json['totalNetMt'] as num?)?.toInt() ?? 0,
      totalNetCash: (json['totalNetCash'] as num?)?.toInt() ?? 0,
      totalCashReceived: (json['totalCashReceived'] as num?)?.toInt() ?? 0,
      totalSalesAmount: (json['totalSalesAmount'] as num?)?.toInt() ?? 0,
      totalRecordCount: (json['totalRecordCount'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshotDate': snapshotDate,
      'totalNetMt': totalNetMt,
      'totalNetCash': totalNetCash,
      'totalCashReceived': totalCashReceived,
      'totalSalesAmount': totalSalesAmount,
      'totalRecordCount': totalRecordCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  String toString() =>
      'ProgressSnapshot(date=$snapshotDate, mt=$totalNetMt, cash=$totalNetCash, '
      'received=$totalCashReceived, sales=$totalSalesAmount, records=$totalRecordCount)';
}
