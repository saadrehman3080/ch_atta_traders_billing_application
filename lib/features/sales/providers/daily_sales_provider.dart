import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_sales_repository.dart';

enum DailySalesState { initial, loading, loaded, error }

class DailySalesProvider extends ChangeNotifier {
  final DailySalesRepository _repository = DailySalesRepository();
  DailySalesState _state = DailySalesState.initial;
  List<SaleHistory> _sales = [];
  String? _errorMessage;

  DailySalesState get state => _state;
  List<SaleHistory> get sales => _sales;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DailySalesState.loading;
  bool get hasError => _state == DailySalesState.error;

  Future<void> loadDailySales(String salesmanName, DateTime date) async {
    _state = DailySalesState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _sales = await _repository.fetchDailySales(salesmanName, date);
      _state = DailySalesState.loaded;
      notifyListeners();
    } catch (e) {
      _state = DailySalesState.error;
      _errorMessage = e.toString();
      _sales = [];
      notifyListeners();
    }
  }

  void clearSales() {
    _sales = [];
    _state = DailySalesState.initial;
    _errorMessage = null;
    notifyListeners();
  }
}
