import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';

enum MtRemainingBillsState { initial, loading, loaded, error }

/// Provider for managing MT remaining bills data state.
///
/// Fetches all credit bills and filters only those created today
/// where cratesDue > 0 (i.e., MT/crates are still remaining).
class MtRemainingBillsProvider extends ChangeNotifier {
  final CreditRepository _creditRepository = CreditRepository();

  MtRemainingBillsState _state = MtRemainingBillsState.initial;
  List<CreditHistory> _mtRemainingBills = [];
  String? _errorMessage;
  bool _isDisposed = false;

  MtRemainingBillsState get state => _state;
  List<CreditHistory> get mtRemainingBills => _mtRemainingBills;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == MtRemainingBillsState.loading;
  bool get hasError => _state == MtRemainingBillsState.error;

  /// Total MT remaining across all bills
  int get totalMtRemaining =>
      _mtRemainingBills.fold<int>(0, (sum, bill) => sum + bill.cratesDue);

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

  /// Loads today's credit bills where cratesDue > 0
  Future<void> loadMtRemainingBills(String salesmanName) async {
    _state = MtRemainingBillsState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final allCredits = await _creditRepository.getAllCreditsForSalesman(
        salesmanName: salesmanName,
      );

      // Filter credits: cratesDue > 0 AND created today
      _mtRemainingBills = allCredits.where((credit) {
        final creditDate = DateTime(
          credit.date.year,
          credit.date.month,
          credit.date.day,
        );
        return credit.cratesDue > 0 && creditDate == today;
      }).toList();

      // Sort by date descending
      _mtRemainingBills.sort((a, b) => b.date.compareTo(a.date));

      _state = MtRemainingBillsState.loaded;
      _safeNotifyListeners();
    } catch (e) {
      _state = MtRemainingBillsState.error;
      _errorMessage = e.toString();
      _mtRemainingBills = [];
      _safeNotifyListeners();
    }
  }

  /// Refreshes the MT remaining bills list
  Future<void> refreshMtRemainingBills(String salesmanName) async {
    await loadMtRemainingBills(salesmanName);
  }
}
