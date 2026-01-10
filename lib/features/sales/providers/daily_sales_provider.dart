import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_sales_repository.dart';

enum DailySalesState { initial, loading, loaded, error }

class DailySalesProvider extends ChangeNotifier {
  final DailySalesRepository _repository = DailySalesRepository();
  DailySalesState _state = DailySalesState.initial;
  List<SaleHistory> _sales = [];
  String? _errorMessage;
  bool _isDisposed = false;

  DailySalesState get state => _state;
  List<SaleHistory> get sales => _sales;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DailySalesState.loading;
  bool get hasError => _state == DailySalesState.error;

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

  Future<void> loadDailySales(String salesmanName, DateTime date) async {
    _state = DailySalesState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      _sales = await _repository.fetchDailySales(salesmanName, date);
      _state = DailySalesState.loaded;
      _safeNotifyListeners();
    } catch (e) {
      _state = DailySalesState.error;
      _errorMessage = e.toString();
      _sales = [];
      _safeNotifyListeners();
    }
  }

  void clearSales() {
    _sales = [];
    _state = DailySalesState.initial;
    _errorMessage = null;
    _safeNotifyListeners();
  }
}
