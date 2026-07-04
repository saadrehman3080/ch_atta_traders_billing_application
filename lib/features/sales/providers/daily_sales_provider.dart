import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_sales_repository.dart';
import 'dart:async';

enum DailySalesState { initial, loading, loaded, error }

class DailySalesProvider extends ChangeNotifier {
  final DailySalesRepository _repository = DailySalesRepository();
  DailySalesState _state = DailySalesState.initial;
  List<SaleHistory> _sales = [];
  String? _errorMessage;
  bool _isDisposed = false;
  StreamSubscription<List<SaleHistory>>? _salesSubscription;
  String? _currentSalesmanName;
  DateTime? _currentDate;

  DailySalesState get state => _state;
  List<SaleHistory> get sales => _sales;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DailySalesState.loading;
  bool get hasError => _state == DailySalesState.error;

  @override
  void dispose() {
    _isDisposed = true;
    _salesSubscription?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> loadDailySales(String salesmanName, DateTime date) async {
    final shouldReuseSubscription =
        _salesSubscription != null &&
        _currentSalesmanName == salesmanName &&
        _currentDate != null &&
        _currentDate!.year == date.year &&
        _currentDate!.month == date.month &&
        _currentDate!.day == date.day;

    if (shouldReuseSubscription) {
      return;
    }

    _currentSalesmanName = salesmanName;
    _currentDate = date;

    _state = DailySalesState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _salesSubscription?.cancel();

      _salesSubscription = _repository
          .watchDailySales(salesmanName, date)
          .listen(
            (sales) {
              _sales = sales;
              _state = DailySalesState.loaded;
              _errorMessage = null;
              _safeNotifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              _state = DailySalesState.error;
              _errorMessage = error.toString();
              _sales = [];
              debugPrint('Daily sales stream error: $error');
              debugPrint('StackTrace: $stackTrace');
              _safeNotifyListeners();
            },
          );
    } catch (e) {
      _state = DailySalesState.error;
      _errorMessage = e.toString();
      _sales = [];
      _safeNotifyListeners();
    }
  }

  Future<bool> deleteSale({
    required SaleHistory sale,
    required String salesmanName,
    bool removeLocally = true,
  }) async {
    try {
      await _repository.deleteSale(sale: sale, salesmanName: salesmanName);

      if (removeLocally) {
        _sales.removeWhere((s) => s.billId == sale.billId);
        _safeNotifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      return false;
    }
  }

  /// Remove a sale from the local list only (used after animation completes)
  void removeSaleLocally(String billId) {
    _sales.removeWhere((s) => s.billId == billId);
    _safeNotifyListeners();
  }

  Future<bool> convertSaleToCredit({
    required SaleHistory sale,
    required String salesmanName,
  }) async {
    try {
      await _repository.convertSaleToCredit(
        sale: sale,
        salesmanName: salesmanName,
      );

      // Remove from local list
      _sales.removeWhere((s) => s.billId == sale.billId);
      _safeNotifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error converting sale to credit: $e');
      return false;
    }
  }

  void clearSales() {
    _sales = [];
    _state = DailySalesState.initial;
    _errorMessage = null;
    _safeNotifyListeners();
  }
}
