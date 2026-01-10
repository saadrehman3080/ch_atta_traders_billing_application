import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';
import 'package:intl/intl.dart';

enum CreditHistoryState { initial, loading, loaded, error }

class CreditHistoryProvider extends ChangeNotifier {
  final CreditRepository _repository = CreditRepository();
  CreditHistoryState _state = CreditHistoryState.initial;
  List<CreditHistory> _credits = [];
  String? _errorMessage;
  DateTime? _lastFetchTime;
  bool _isDisposed = false;

  CreditHistoryState get state => _state;
  List<CreditHistory> get credits => _credits;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == CreditHistoryState.loading;
  bool get hasError => _state == CreditHistoryState.error;
  DateTime? get lastFetchTime => _lastFetchTime;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Loads all credit history records for a salesman across all dates
  /// Uses optimized parallel queries with configurable parameters
  ///
  /// [salesmanName] - The name of the salesman
  /// [daysToLookBack] - Number of days to look back (default: 30 days)
  /// [batchSize] - Number of concurrent queries (default: 10 for optimal performance)
  /// [forceRefresh] - Skip cache and force fresh data (default: false)
  Future<void> loadAllCreditHistory(
    String salesmanName, {
    int daysToLookBack = 30,
    int batchSize = 10,
    bool forceRefresh = false,
  }) async {
    // Check if we have recent data and don't need to refresh
    if (!forceRefresh &&
        _credits.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) <
            const Duration(minutes: 5)) {
      print(
        'Using cached credit data (fetched ${DateTime.now().difference(_lastFetchTime!).inSeconds}s ago)',
      );
      return;
    }

    _state = CreditHistoryState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final startTime = DateTime.now();

      _credits = await _repository.getAllCreditsForSalesman(
        salesmanName: salesmanName,
        daysToLookBack: daysToLookBack,
        batchSize: batchSize,
      );

      _lastFetchTime = DateTime.now();
      _state = CreditHistoryState.loaded;

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      print(
        'Credit history loaded in ${loadTime}ms (${_credits.length} records)',
      );

      _safeNotifyListeners();
    } catch (e) {
      _state = CreditHistoryState.error;
      _errorMessage = e.toString();
      _credits = [];
      _lastFetchTime = null;
      _safeNotifyListeners();
    }
  }

  /// Clears the cache and resets state
  void clearCredits() {
    _credits = [];
    _state = CreditHistoryState.initial;
    _errorMessage = null;
    _lastFetchTime = null;
    _safeNotifyListeners();
  }

  /// Forces a refresh of credit data
  Future<void> refreshCreditHistory(String salesmanName) async {
    await loadAllCreditHistory(salesmanName, forceRefresh: true);
  }

  /// Updates the amountDue and/or cratesDue for a specific credit record
  /// Returns true if update was successful, false otherwise
  Future<bool> updateCreditBalance({
    required String salesmanName,
    required CreditHistory credit,
    int? newAmountDue,
    int? newCratesDue,
    bool? isPaid,
  }) async {
    try {
      // Format date as dd-MMM-yyyy (e.g., 01-Jan-2026)
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final formattedDate = dateFormat.format(credit.date);

      await _repository.updateCreditBalance(
        salesmanName: salesmanName,
        date: formattedDate,
        billId: credit.billId,
        newAmountDue: newAmountDue,
        newCratesDue: newCratesDue,
        isPaid: isPaid,
      );

      // Update local cache
      final index = _credits.indexWhere((c) => c.billId == credit.billId);
      if (index != -1) {
        final updatedCredit = CreditHistory(
          billId: credit.billId,
          customerName: credit.customerName,
          date: credit.date,
          products: credit.products,
          discount: credit.discount,
          amountDue: newAmountDue ?? credit.amountDue,
          cratesDue: newCratesDue ?? credit.cratesDue,
          isPaid: isPaid ?? credit.isPaid,
        );
        _credits[index] = updatedCredit;
        _safeNotifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error updating credit balance: $e');
      return false;
    }
  }
}
