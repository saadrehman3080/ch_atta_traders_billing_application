import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:ch_atta_traders_billing_application/data/models/progress_snapshot.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_progress_repository.dart';
import 'package:intl/intl.dart';

/// Provider for managing daily progress state.
///
/// **Optimised loading strategy:**
/// On the very first load the full history is fetched once, a snapshot document
/// is written to Firestore that captures cumulative totals for records older
/// than [_snapshotWindowMonths], and only the recent window is kept in memory.
///
/// On subsequent loads, only the snapshot (1 Firestore read) plus the recent
/// window of records are fetched – saving bandwidth, time, and Firestore costs
/// as the dataset grows over months and years.
///
/// The all‑time totals (MT / Cash) displayed in the UI are always:
///   **snapshot totals  +  sum of recent records**
class DailyProgressProvider extends ChangeNotifier {
  final DailyProgressRepository _repository;

  DailyProgressProvider({DailyProgressRepository? repository})
    : _repository = repository ?? DailyProgressRepository();

  // ========================= Configuration =========================

  /// How many months of recent data we keep in memory / fetch from Firestore.
  static const int _snapshotWindowMonths = 6;

  /// Number of records shown in the UI before the user taps "Load More".
  static const int _pageSize = 30;

  // ========================= State =================================

  /// Running‑total snapshot for all records older than the window.
  ProgressSnapshot _snapshot = ProgressSnapshot.empty();

  /// **All** records that live *after* the snapshot date (the recent window).
  /// Used to compute accurate all‑time totals.
  List<DailyProgress> _recentRecords = [];

  /// Subset of [_recentRecords] currently displayed in the list view.
  List<DailyProgress> _displayedRecords = [];

  /// How many records we're currently showing.
  int _displayCount = _pageSize;

  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  // ========================= Getters ===============================

  /// Records currently visible in the list view (paginated).
  List<DailyProgress> get progressList => _displayedRecords;

  /// All recent records (after the snapshot). Used internally and for
  /// monthly aggregates.
  List<DailyProgress> get allRecentRecords => _recentRecords;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// Whether there are more records to show beyond the current page.
  bool get hasMoreRecords => _displayCount < _recentRecords.length;

  /// Absolute total number of records (snapshot + recent).
  int get totalRecordCount =>
      _snapshot.totalRecordCount + _recentRecords.length;

  // ========== Aggregated All-Time Totals (MT & Cash) ===============

  /// Net MT balance across **all** records (snapshot + recent).
  int get totalNetMt {
    int recentMt = 0;
    for (final p in _recentRecords) {
      recentMt += p.emptyCrates.excess;
      recentMt -= p.emptyCrates.short;
    }
    return _snapshot.totalNetMt + recentMt;
  }

  int get totalMtShort => totalNetMt < 0 ? totalNetMt.abs() : 0;
  int get totalMtExcess => totalNetMt > 0 ? totalNetMt : 0;

  /// Net cash balance across **all** records (snapshot + recent).
  int get totalNetCash {
    final recentCash = _recentRecords.fold<int>(
      0,
      (sum, p) => sum + p.finalAmount,
    );
    return _snapshot.totalNetCash + recentCash;
  }

  int get totalCashShort => totalNetCash > 0 ? totalNetCash : 0;
  int get totalCashExcess => totalNetCash < 0 ? totalNetCash.abs() : 0;

  /// Total cash received across **all** records.
  int get totalCashReceived {
    final recentReceived = _recentRecords.fold<int>(
      0,
      (sum, p) => sum + p.cashReceived,
    );
    return _snapshot.totalCashReceived + recentReceived;
  }

  /// Total sales amount across **all** records.
  int get totalSalesAmountAll {
    final recentSales = _recentRecords.fold<int>(
      0,
      (sum, p) => sum + p.totalSalesAmount,
    );
    return _snapshot.totalSalesAmount + recentSales;
  }

  // ========== Monthly Aggregates (computed from recent records) =====

  List<DailyProgress> get currentMonthRecords {
    final now = DateTime.now();
    return _recentRecords.where((p) {
      try {
        final date = DateTime.parse(p.date);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int get monthlySalesAmount =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalSalesAmount);

  int get monthlyItemsSold =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalItemsSold);

  int get monthlyTotalExpenses =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalExpenses);

  int get monthlyDaysWorked => currentMonthRecords.length;

  // ========================= Public Methods ========================

  /// Primary entry point – loads snapshot + recent records.
  Future<void> loadProgressList(String salesmanDocId) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final cutoffDate = _computeCutoffDate();

      // 1. Try to load the existing snapshot.
      final existingSnapshot = await _repository.fetchProgressSnapshot(
        salesmanDocId,
      );

      if (existingSnapshot != null &&
          existingSnapshot.snapshotDate.isNotEmpty) {
        // ── Snapshot exists ──────────────────────────────────────────────
        _snapshot = existingSnapshot;

        // Fetch only records after the snapshot date.
        final fetchedRecords = await _repository.fetchProgressAfterDate(
          salesmanDocId,
          _snapshot.snapshotDate,
        );

        // Partition into "gap" (older than cutoff) and "recent" (within window).
        final gap = <DailyProgress>[];
        final recent = <DailyProgress>[];
        for (final r in fetchedRecords) {
          if (r.date.compareTo(cutoffDate) <= 0) {
            gap.add(r);
          } else {
            recent.add(r);
          }
        }

        // If there are gap records, absorb them into the snapshot.
        if (gap.isNotEmpty) {
          _snapshot = _absorbIntoSnapshot(_snapshot, gap, cutoffDate);
          // Fire‑and‑forget – don't block UI on write.
          _repository
              .saveProgressSnapshot(salesmanDocId, _snapshot)
              .catchError((_) {});
        }

        _recentRecords = recent;
      } else {
        // ── No snapshot yet (first‑time load) ────────────────────────────
        // Fetch ALL records once so we can create the initial snapshot.
        final allRecords = await _repository.fetchDailyProgressList(
          salesmanDocId,
        );

        final old = <DailyProgress>[];
        final recent = <DailyProgress>[];
        for (final r in allRecords) {
          if (r.date.compareTo(cutoffDate) <= 0) {
            old.add(r);
          } else {
            recent.add(r);
          }
        }

        if (old.isNotEmpty) {
          _snapshot = _absorbIntoSnapshot(
            ProgressSnapshot.empty(),
            old,
            cutoffDate,
          );
          _repository
              .saveProgressSnapshot(salesmanDocId, _snapshot)
              .catchError((_) {});
        } else {
          _snapshot = ProgressSnapshot.empty();
        }

        _recentRecords = recent;
      }

      // Sort recent records: newest first.
      _recentRecords.sort((a, b) => b.date.compareTo(a.date));

      // Reset pagination and populate displayed list.
      _displayCount = _pageSize;
      _updateDisplayedRecords();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Failed to load progress data. Please try again.';
      debugPrint('Error loading progress list: $e');
      notifyListeners();
    }
  }

  /// Refresh the progress list (same as load).
  Future<void> refreshProgressList(String salesmanDocId) async {
    await loadProgressList(salesmanDocId);
  }

  /// Show the next page of records in the UI list.
  void loadMore() {
    _displayCount = (_displayCount + _pageSize).clamp(0, _recentRecords.length);
    _updateDisplayedRecords();
    notifyListeners();
  }

  // ========================= Private Helpers =======================

  /// Returns the YYYY‑MM‑DD cutoff date ([_snapshotWindowMonths] ago).
  String _computeCutoffDate() {
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month - _snapshotWindowMonths,
      now.day,
    );
    return DateFormat('yyyy-MM-dd').format(cutoff);
  }

  /// Absorbs [records] into [base] snapshot, returning a new snapshot with
  /// the combined totals and [newSnapshotDate] as the boundary.
  ProgressSnapshot _absorbIntoSnapshot(
    ProgressSnapshot base,
    List<DailyProgress> records,
    String newSnapshotDate,
  ) {
    int addedNetMt = 0;
    int addedNetCash = 0;
    int addedCashReceived = 0;
    int addedSalesAmount = 0;

    for (final r in records) {
      addedNetMt += r.emptyCrates.excess;
      addedNetMt -= r.emptyCrates.short;
      addedNetCash += r.finalAmount;
      addedCashReceived += r.cashReceived;
      addedSalesAmount += r.totalSalesAmount;
    }

    return ProgressSnapshot(
      snapshotDate: newSnapshotDate,
      totalNetMt: base.totalNetMt + addedNetMt,
      totalNetCash: base.totalNetCash + addedNetCash,
      totalCashReceived: base.totalCashReceived + addedCashReceived,
      totalSalesAmount: base.totalSalesAmount + addedSalesAmount,
      totalRecordCount: base.totalRecordCount + records.length,
    );
  }

  /// Refreshes [_displayedRecords] from [_recentRecords] respecting
  /// the current [_displayCount].
  void _updateDisplayedRecords() {
    final count = _displayCount.clamp(0, _recentRecords.length);
    _displayedRecords = _recentRecords.sublist(0, count);
  }
}
