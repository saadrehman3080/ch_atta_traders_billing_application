import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/sale_repository.dart';

/// Sale saving state enum
enum SaleState { initial, saving, saved, error }

/// ViewModel for sale operations.
///
/// This class follows the MVVM pattern, managing sale state
/// and coordinating between the View and Repository layers.
class SaleProvider extends ChangeNotifier {
  final SaleRepository _repository;

  SaleProvider({SaleRepository? repository})
    : _repository = repository ?? SaleRepository();

  // ========== State Management ==========
  SaleState _state = SaleState.initial;
  String? _errorMessage;
  SaleHistory? _lastSavedSale;

  /// Current sale saving state
  SaleState get state => _state;

  /// Error message if saving failed
  String? get errorMessage => _errorMessage;

  /// Last successfully saved sale
  SaleHistory? get lastSavedSale => _lastSavedSale;

  /// Whether sale is being saved
  bool get isSaving => _state == SaleState.saving;

  /// Whether sale was saved successfully
  bool get isSaved => _state == SaleState.saved;

  // ========== Sale Methods ==========

  /// Saves a sale to Firebase.
  ///
  /// [sale] - The SaleHistory object to save
  /// [salesmanName] - The name of the salesman (from SharedPreferences)
  ///
  /// Returns true if save was successful, false otherwise.
  Future<bool> saveSale(SaleHistory sale, String salesmanName) async {
    _setState(SaleState.saving);
    _errorMessage = null;

    try {
      final success = await _repository.saveSale(sale, salesmanName);

      if (success) {
        _lastSavedSale = sale;
        _setState(SaleState.saved);
        debugPrint('Sale saved successfully: ${sale.billId}');
        return true;
      } else {
        _errorMessage = 'Failed to save sale. Please try again.';
        _setState(SaleState.error);
        debugPrint('Failed to save sale');
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred while saving. Please try again.';
      _setState(SaleState.error);
      debugPrint('Error saving sale: $e');
      return false;
    }
  }

  /// Saves a sale converted from credit WITHOUT incrementing customersServed.
  /// Used when moving a credit record to sale history after full payment.
  ///
  /// [sale] - The SaleHistory object to save
  /// [salesmanName] - The name of the salesman
  ///
  /// Returns true if save was successful, false otherwise.
  Future<bool> saveSaleFromCreditConversion(
    SaleHistory sale,
    String salesmanName,
  ) async {
    _setState(SaleState.saving);
    _errorMessage = null;

    try {
      final success = await _repository.saveSaleFromCreditConversion(
        sale,
        salesmanName,
      );

      if (success) {
        _lastSavedSale = sale;
        _setState(SaleState.saved);
        debugPrint('Sale from credit conversion saved: ${sale.billId}');
        return true;
      } else {
        _errorMessage = 'Failed to save sale. Please try again.';
        _setState(SaleState.error);
        debugPrint('Failed to save sale from credit conversion');
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred while saving. Please try again.';
      _setState(SaleState.error);
      debugPrint('Error saving sale from credit conversion: $e');
      return false;
    }
  }

  /// Resets the sale state to initial.
  void resetState() {
    _errorMessage = null;
    _lastSavedSale = null;
    _setState(SaleState.initial);
  }

  // ========== Private Methods ==========

  void _setState(SaleState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('SaleProvider disposed');
    super.dispose();
  }
}
