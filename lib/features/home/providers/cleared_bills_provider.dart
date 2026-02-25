import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/cleared_bill.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/cleared_bill_repository.dart';

enum ClearedBillsState { initial, loading, loaded, error }

/// Provider for managing the state of cleared bills
/// (previous day bills that were fully paid today).
class ClearedBillsProvider extends ChangeNotifier {
  final ClearedBillRepository _repository = ClearedBillRepository();

  ClearedBillsState _state = ClearedBillsState.initial;
  List<ClearedBill> _clearedBills = [];
  String? _errorMessage;
  bool _isDisposed = false;

  ClearedBillsState get state => _state;
  List<ClearedBill> get clearedBills => _clearedBills;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ClearedBillsState.loading;
  bool get hasError => _state == ClearedBillsState.error;

  /// Total cash collected from cleared bills today
  int get totalCashCollected {
    return _clearedBills.fold(0, (sum, bill) => sum + bill.amountPaidToday);
  }

  /// Total crates returned from cleared bills today
  int get totalCratesReturned {
    return _clearedBills.fold(0, (sum, bill) => sum + bill.cratesReturnedToday);
  }

  /// Number of fully cleared bills
  int get fullyClearedCount {
    return _clearedBills.where((b) => !b.isPartialPayment).length;
  }

  /// Number of partial payment entries
  int get partialPaymentCount {
    return _clearedBills.where((b) => b.isPartialPayment).length;
  }

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

  /// Load cleared bills for the given salesman (today's date)
  Future<void> loadClearedBills(String salesmanName) async {
    _state = ClearedBillsState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      _clearedBills = await _repository.getClearedBills(
        salesmanName: salesmanName,
      );
      _state = ClearedBillsState.loaded;
      _safeNotifyListeners();
    } catch (e) {
      _state = ClearedBillsState.error;
      _errorMessage = e.toString();
      _clearedBills = [];
      _safeNotifyListeners();
    }
  }

  /// Refresh cleared bills data
  Future<void> refreshClearedBills(String salesmanName) async {
    await loadClearedBills(salesmanName);
  }
}
