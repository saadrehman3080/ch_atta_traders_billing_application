import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_progress_repository.dart';

/// Provider for managing daily progress state.
class DailyProgressProvider extends ChangeNotifier {
  final DailyProgressRepository _repository;

  DailyProgressProvider({DailyProgressRepository? repository})
    : _repository = repository ?? DailyProgressRepository();

  // ========== State ==========
  List<DailyProgress> _progressList = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  // ========== Getters ==========
  List<DailyProgress> get progressList => _progressList;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  // ========== Aggregated All-Time Totals (MT & Cash) ==========

  /// Net MT balance across ALL records: positive = excess, negative = short
  int get totalNetMt {
    int net = 0;
    for (final p in _progressList) {
      net += p.emptyCrates.excess;
      net -= p.emptyCrates.short;
    }
    return net;
  }

  /// Total MT short across all records (absolute, only if net is negative)
  int get totalMtShort => totalNetMt < 0 ? totalNetMt.abs() : 0;

  /// Total MT excess across all records (only if net is positive)
  int get totalMtExcess => totalNetMt > 0 ? totalNetMt : 0;

  /// Net cash balance across ALL records: sum of all finalAmount
  /// positive = excess, negative = short
  int get totalNetCash {
    return _progressList.fold<int>(0, (sum, p) => sum + p.finalAmount);
  }

  /// Total cash short (absolute, only if net is negative)
  int get totalCashShort => totalNetCash < 0 ? totalNetCash.abs() : 0;

  /// Total cash excess (only if net is positive)
  int get totalCashExcess => totalNetCash > 0 ? totalNetCash : 0;

  /// Total cash received across ALL records
  int get totalCashReceived =>
      _progressList.fold<int>(0, (sum, p) => sum + p.cashReceived);

  /// Total sales amount across ALL records
  int get totalSalesAmountAll =>
      _progressList.fold<int>(0, (sum, p) => sum + p.totalSalesAmount);

  // ========== Monthly Aggregates ==========

  /// Get records for the current month
  List<DailyProgress> get currentMonthRecords {
    final now = DateTime.now();
    return _progressList.where((p) {
      try {
        final date = DateTime.parse(p.date);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// Monthly total sales amount
  int get monthlySalesAmount =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalSalesAmount);

  /// Monthly total items sold
  int get monthlyItemsSold =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalItemsSold);

  /// Monthly total expenses
  int get monthlyTotalExpenses =>
      currentMonthRecords.fold<int>(0, (sum, p) => sum + p.totalExpenses);

  /// Monthly days worked
  int get monthlyDaysWorked => currentMonthRecords.length;

  // ========== Methods ==========

  /// Load all daily progress records for a salesman.
  Future<void> loadProgressList(String salesmanDocId) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      _progressList = await _repository.fetchDailyProgressList(salesmanDocId);
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

  /// Refresh the progress list.
  Future<void> refreshProgressList(String salesmanDocId) async {
    await loadProgressList(salesmanDocId);
  }
}
