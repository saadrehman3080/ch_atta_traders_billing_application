import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';

enum CreditState { initial, saving, saved, error }

class CreditProvider extends ChangeNotifier {
  final CreditRepository _repository = CreditRepository();
  CreditState _state = CreditState.initial;
  String? _errorMessage;

  CreditState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _state == CreditState.saving;

  Future<bool> saveCredit(CreditHistory credit, String salesmanName) async {
    _state = CreditState.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveCredit(credit, salesmanName);
      _state = CreditState.saved;
      notifyListeners();
      return true;
    } catch (e) {
      _state = CreditState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
