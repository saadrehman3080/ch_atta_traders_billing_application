import 'package:flutter/foundation.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';
import 'dart:async';

enum CreditHistoryState { initial, loading, loaded, error }

class CreditHistoryProvider extends ChangeNotifier {
  final CreditRepository _repository = CreditRepository();
  CreditHistoryState _state = CreditHistoryState.initial;
  List<CreditHistory> _credits = [];
  String? _errorMessage;
  DateTime? _lastFetchTime;
  bool _isDisposed = false;
  StreamSubscription<List<CreditHistory>>? _creditSubscription;
  String? _currentSalesmanName;

  CreditHistoryState get state => _state;
  List<CreditHistory> get credits => _credits;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == CreditHistoryState.loading;
  bool get hasError => _state == CreditHistoryState.error;
  DateTime? get lastFetchTime => _lastFetchTime;

  @override
  void dispose() {
    _isDisposed = true;
    _creditSubscription?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Loads all credit history records for a salesman
  /// Uses single query to bills subcollection
  ///
  /// [salesmanName] - The name of the salesman
  /// [forceRefresh] - Skip cache and force fresh data (default: false)
  Future<void> loadAllCreditHistory(
    String salesmanName, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _creditSubscription != null &&
        _currentSalesmanName == salesmanName) {
      return;
    }

    _currentSalesmanName = salesmanName;
    _state = CreditHistoryState.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _creditSubscription?.cancel();

      _creditSubscription = _repository
          .watchAllCreditsForSalesman(salesmanName: salesmanName)
          .listen(
            (credits) {
              _credits = credits;
              _lastFetchTime = DateTime.now();
              _state = CreditHistoryState.loaded;
              _errorMessage = null;
              _safeNotifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              _state = CreditHistoryState.error;
              _errorMessage = error.toString();
              _credits = [];
              _lastFetchTime = null;
              debugPrint('Credit history stream error: $error');
              debugPrint('StackTrace: $stackTrace');
              _safeNotifyListeners();
            },
          );
    } catch (e) {
      _state = CreditHistoryState.error;
      _errorMessage = e.toString();
      _credits = [];
      _lastFetchTime = null;
      _safeNotifyListeners();
    }
  }

  /// Clears the cache and resets state
  void clearCredits() {
    _credits = [];
    _state = CreditHistoryState.initial;
    _errorMessage = null;
    _lastFetchTime = null;
    _creditSubscription?.cancel();
    _creditSubscription = null;
    _currentSalesmanName = null;
    _safeNotifyListeners();
  }

  /// Forces a refresh of credit data
  Future<void> refreshCreditHistory(String salesmanName) async {
    await loadAllCreditHistory(salesmanName, forceRefresh: true);
  }

  /// Updates the amountDue and/or cratesDue for a specific credit record
  /// Returns true if update was successful, false otherwise
  Future<bool> updateCreditBalance({
    required String salesmanName,
    required CreditHistory credit,
    int? newAmountDue,
    int? newCratesDue,
    bool? isPaid,
    bool? isRecordUpdated,
    PartialPayment? newPartialPayment,
  }) async {
    try {
      await _repository.updateCreditBalance(
        salesmanName: salesmanName,
        billId: credit.billId,
        newAmountDue: newAmountDue,
        newCratesDue: newCratesDue,
        isPaid: isPaid,
        isRecordUpdated: isRecordUpdated,
        newPartialPayment: newPartialPayment,
      );

      // Update local cache
      final index = _credits.indexWhere((c) => c.billId == credit.billId);
      if (index != -1) {
        final updatedPartialPayments = [
          ...credit.partialPayments,
          if (newPartialPayment != null) newPartialPayment,
        ];
        final updatedCredit = CreditHistory(
          billId: credit.billId,
          customerName: credit.customerName,
          date: credit.date,
          products: credit.products,
          discount: credit.discount,
          isReceiptGenerated: credit.isReceiptGenerated,
          amountDue: newAmountDue ?? credit.amountDue,
          cratesDue: newCratesDue ?? credit.cratesDue,
          isPaid: isPaid ?? credit.isPaid,
          isRecordUpdated: isRecordUpdated ?? credit.isRecordUpdated,
          partialPayments: updatedPartialPayments,
          latitude: credit.latitude,
          longitude: credit.longitude,
        );
        _credits[index] = updatedCredit;
        _safeNotifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error updating credit balance: $e');
      return false;
    }
  }

  /// Deletes a credit record from Firestore
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteCreditRecord({
    required String billId,
    required String salesmanName,
    bool removeLocally = true,
  }) async {
    try {
      // Verify the credit exists in local cache
      if (!_credits.any((c) => c.billId == billId)) {
        throw Exception('Credit record not found in cache');
      }

      // Delete from Firebase
      await _repository.deleteCredit(
        salesmanName: salesmanName,
        billId: billId,
      );

      if (removeLocally) {
        // Remove from local cache
        _credits.removeWhere((c) => c.billId == billId);
        _safeNotifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting credit record: $e');
      return false;
    }
  }

  /// Remove a credit record from the local list only (used after animation completes)
  void removeCreditLocally(String billId) {
    _credits.removeWhere((c) => c.billId == billId);
    _safeNotifyListeners();
  }

  /// Saves a credit record to delete history
  /// Returns true if save was successful, false otherwise
  Future<bool> saveCreditToDeleteHistory({
    required String path,
    required CreditHistory credit,
  }) async {
    try {
      await _repository.saveCreditToDeleteHistory(path: path, credit: credit);
      return true;
    } catch (e) {
      debugPrint('Error saving credit to delete history: $e');
      return false;
    }
  }
}
