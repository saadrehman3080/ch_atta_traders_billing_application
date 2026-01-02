import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';

enum CreditHistoryState { initial, loading, loaded, error }

class CreditHistoryProvider extends ChangeNotifier {
  final CreditRepository _repository = CreditRepository();
  CreditHistoryState _state = CreditHistoryState.initial;
  List<CreditHistory> _credits = [];
  String? _errorMessage;
  DateTime? _lastFetchTime;

  CreditHistoryState get state => _state;
  List<CreditHistory> get credits => _credits;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == CreditHistoryState.loading;
  bool get hasError => _state == CreditHistoryState.error;
  DateTime? get lastFetchTime => _lastFetchTime;

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
    notifyListeners();

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

      notifyListeners();
    } catch (e) {
      _state = CreditHistoryState.error;
      _errorMessage = e.toString();
      _credits = [];
      _lastFetchTime = null;
      notifyListeners();
    }
  }

  /// Clears the cache and resets state
  void clearCredits() {
    _credits = [];
    _state = CreditHistoryState.initial;
    _errorMessage = null;
    _lastFetchTime = null;
    notifyListeners();
  }

  /// Forces a refresh of credit data
  Future<void> refreshCreditHistory(String salesmanName) async {
    await loadAllCreditHistory(salesmanName, forceRefresh: true);
  }
}
