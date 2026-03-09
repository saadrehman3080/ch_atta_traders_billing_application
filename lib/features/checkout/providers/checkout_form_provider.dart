import 'package:flutter/foundation.dart';

/// Holds the checkout form state so it survives bottom-sheet dismiss/reopen.
/// Lives in [OrderPage] and is passed to [CheckoutPage] via constructor.
class CheckoutFormProvider extends ChangeNotifier {
  String _customerName = '';
  String _paymentType = 'cash';
  int _discount = 0;
  int _mt = 0;
  int _partialPayment = 0;
  bool _isAnonymousCustomer = false;

  /// Whether this provider has been populated at least once
  /// (used to decide whether to apply default preferences).
  bool _hasBeenOpened = false;

  // -- Getters --
  String get customerName => _customerName;
  String get paymentType => _paymentType;
  int get discount => _discount;
  int get mt => _mt;
  int get partialPayment => _partialPayment;
  bool get isAnonymousCustomer => _isAnonymousCustomer;
  bool get hasBeenOpened => _hasBeenOpened;

  // -- Setters (called from CheckoutPage dispose / on change) --
  set customerName(String value) {
    _customerName = value;
    notifyListeners();
  }

  set paymentType(String value) {
    _paymentType = value;
    notifyListeners();
  }

  set discount(int value) {
    _discount = value;
    notifyListeners();
  }

  set mt(int value) {
    _mt = value;
    notifyListeners();
  }

  set partialPayment(int value) {
    _partialPayment = value;
    notifyListeners();
  }

  set isAnonymousCustomer(bool value) {
    _isAnonymousCustomer = value;
    notifyListeners();
  }

  /// Mark that the checkout sheet has been opened at least once.
  void markOpened() {
    _hasBeenOpened = true;
  }

  /// Silently save all fields at once (e.g. from CheckoutPage.dispose)
  /// without triggering rebuilds.
  void saveState({
    required String customerName,
    required String paymentType,
    required int discount,
    required int mt,
    required int partialPayment,
    required bool isAnonymousCustomer,
  }) {
    _customerName = customerName;
    _paymentType = paymentType;
    _discount = discount;
    _mt = mt;
    _partialPayment = partialPayment;
    _isAnonymousCustomer = isAnonymousCustomer;
    _hasBeenOpened = true;
  }

  /// Reset all fields after a successful sale.
  void reset() {
    _customerName = '';
    _paymentType = 'cash';
    _discount = 0;
    _mt = 0;
    _partialPayment = 0;
    _isAnonymousCustomer = false;
    _hasBeenOpened = false;
    notifyListeners();
  }
}
