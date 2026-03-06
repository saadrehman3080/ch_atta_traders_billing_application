import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/daily_sales_repository.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';

enum DiscountedBillsState { initial, loading, loaded, error }

/// Provider for managing discounted bills data state.
///
/// Fetches today's sales from Daily Sales AND all credit bills,
/// filters only those where discount > 0 and (for credits) created today.
/// This ensures the total matches the dashboard discount value.
class DiscountedBillsProvider extends ChangeNotifier {
  final DailySalesRepository _salesRepository = DailySalesRepository();
  final CreditRepository _creditRepository = CreditRepository();

  DiscountedBillsState _state = DiscountedBillsState.initial;
  List<BillBase> _discountedBills = [];
  String? _errorMessage;
  bool _isDisposed = false;

  DiscountedBillsState get state => _state;
  List<BillBase> get discountedBills => _discountedBills;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DiscountedBillsState.loading;
  bool get hasError => _state == DiscountedBillsState.error;

  /// Total discount amount across all discounted bills
  int get totalDiscountAmount =>
      _discountedBills.fold<int>(0, (sum, bill) => sum + bill.discount);

  /// Count of cash sale bills with discount
  int get cashBillCount => _discountedBills.whereType<SaleHistory>().length;

  /// Count of credit bills with discount
  int get creditBillCount => _discountedBills.whereType<CreditHistory>().length;

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

  /// Loads today's sales AND today's credit bills, filters for discount > 0
  Future<void> loadDiscountedBills(String salesmanName) async {
    _state = DiscountedBillsState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Fetch both sources in parallel
      final results = await Future.wait([
        _salesRepository.fetchDailySales(salesmanName, now),
        _creditRepository.getAllCreditsForSalesman(salesmanName: salesmanName),
      ]);

      final allSales = results[0] as List<SaleHistory>;
      final allCredits = results[1] as List<CreditHistory>;

      // Filter sales with discount > 0 (already today's only)
      final discountedSales = allSales
          .where((sale) => sale.discount > 0)
          .toList();

      // Filter credits: discount > 0 AND created today
      final discountedCredits = allCredits.where((credit) {
        final creditDate = DateTime(
          credit.date.year,
          credit.date.month,
          credit.date.day,
        );
        return credit.discount > 0 && creditDate == today;
      }).toList();

      // Combine and sort by date descending
      _discountedBills = [...discountedSales, ...discountedCredits];
      _discountedBills.sort((a, b) => b.date.compareTo(a.date));

      _state = DiscountedBillsState.loaded;
      _safeNotifyListeners();
    } catch (e) {
      _state = DiscountedBillsState.error;
      _errorMessage = e.toString();
      _discountedBills = [];
      _safeNotifyListeners();
    }
  }

  /// Refreshes the discounted bills list
  Future<void> refreshDiscountedBills(String salesmanName) async {
    await loadDiscountedBills(salesmanName);
  }
}
