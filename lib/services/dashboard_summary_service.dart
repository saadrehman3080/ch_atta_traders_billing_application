import 'package:ch_atta_traders_billing_application/core/utils/date_formatters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for managing dashboard summary operations.
/// Handles all increment/decrement operations for dashboard fields.
class DashboardSummaryService {
  final FirebaseFirestore _firestore;

  // Singleton instance
  static final DashboardSummaryService _instance =
      DashboardSummaryService._internal();

  factory DashboardSummaryService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return DashboardSummaryService._withFirestore(firestore);
    }
    return _instance;
  }

  DashboardSummaryService._internal() : _firestore = FirebaseFirestore.instance;

  DashboardSummaryService._withFirestore(this._firestore);

  /// Gets the summary document reference for a specific date
  DocumentReference _getSummaryRef(String salesmanName, DateTime date) {
    final formattedDate = DateFormatters.formatForFirebase(date);
    return _firestore
        .collection('Dashboard Summary')
        .doc(salesmanName)
        .collection(formattedDate)
        .doc('summary');
  }

  /// Checks if the given date is today
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  // ========== SALE OPERATIONS ==========

  /// Updates dashboard when a new CASH sale is created (no MT tracking).
  /// Increments: totalCollection, totalItemsSold, totalDiscount, customersServed
  Future<void> onSaleCreated({
    required String salesmanName,
    required DateTime date,
    required int totalAmount,
    required int itemsSold,
    required int discount,
    Transaction? transaction,
  }) async {
    debugPrint('DashboardSummaryService: onSaleCreated');
    debugPrint('Amount: $totalAmount, Items: $itemsSold, Discount: $discount');

    final summaryRef = _getSummaryRef(salesmanName, date);
    final updates = {
      'totalCollection': FieldValue.increment(totalAmount),
      'totalItemsSold': FieldValue.increment(itemsSold),
      'totalDiscount': FieldValue.increment(discount),
      'customersServed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (transaction != null) {
      transaction.set(summaryRef, updates, SetOptions(merge: true));
    } else {
      await summaryRef.set(updates, SetOptions(merge: true));
    }
  }

  /// Updates dashboard when a sale is deleted.
  /// Decrements: totalCollection, totalItemsSold, totalDiscount, customersServed
  /// Only updates if the sale is from today.
  Future<bool> onSaleDeleted({
    required String salesmanName,
    required DateTime date,
    required int totalAmount,
    required int itemsSold,
    required int discount,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Sale not from today, skipping update',
      );
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onSaleDeleted');
      debugPrint(
        'Amount: $totalAmount, Items: $itemsSold, Discount: $discount',
      );

      final summaryRef = _getSummaryRef(salesmanName, date);
      await summaryRef.set({
        'totalCollection': FieldValue.increment(-totalAmount),
        'totalItemsSold': FieldValue.increment(-itemsSold),
        'totalDiscount': FieldValue.increment(-discount),
        'customersServed': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onSaleDeleted: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  // ========== CREDIT OPERATIONS ==========

  /// Updates dashboard when a new credit is created.
  /// Increments: totalCredit (if not paid), totalItemsSold, totalMtRemaining, totalDiscount, customersServed
  Future<void> onCreditCreated({
    required String salesmanName,
    required DateTime date,
    required int creditAmount,
    required int itemsSold,
    required int mtRemaining,
    required int discount,
    required bool isPaid,
    Transaction? transaction,
  }) async {
    debugPrint('DashboardSummaryService: onCreditCreated');
    debugPrint(
      'Credit: $creditAmount, Items: $itemsSold, MT: $mtRemaining, Discount: $discount, IsPaid: $isPaid',
    );

    final summaryRef = _getSummaryRef(salesmanName, date);

    // Only add to credit if not already paid (cash with MT tracking)
    final actualCreditAmount = isPaid ? 0 : creditAmount;

    final updates = {
      'totalCredit': FieldValue.increment(actualCreditAmount),
      'totalItemsSold': FieldValue.increment(itemsSold),
      'totalMtRemaining': FieldValue.increment(mtRemaining),
      'totalDiscount': FieldValue.increment(discount),
      'customersServed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (transaction != null) {
      transaction.set(summaryRef, updates, SetOptions(merge: true));
    } else {
      await summaryRef.set(updates, SetOptions(merge: true));
    }
  }

  /// Updates dashboard when a credit is deleted permanently.
  /// Decrements: totalCredit (if not paid), totalItemsSold, totalMtRemaining, totalDiscount, customersServed
  /// Only updates if the credit is from today.
  Future<bool> onCreditDeleted({
    required String salesmanName,
    required DateTime date,
    required int amountDue,
    required int cratesDue,
    required int itemsSold,
    required int discount,
    required bool isPaidBill,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Credit not from today, skipping update',
      );
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onCreditDeleted');
      debugPrint(
        'Amount: $amountDue, Crates: $cratesDue, Items: $itemsSold, Discount: $discount, WasPaid: $isPaidBill',
      );

      final summaryRef = _getSummaryRef(salesmanName, date);
      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Decrement credit if bill was not paid
      if (amountDue > 0 && !isPaidBill) {
        updates['totalCredit'] = FieldValue.increment(-amountDue);
      }

      // Decrement MT remaining if there were crates due
      if (cratesDue > 0) {
        updates['totalMtRemaining'] = FieldValue.increment(-cratesDue);
      }

      // Decrement items sold
      if (itemsSold > 0) {
        updates['totalItemsSold'] = FieldValue.increment(-itemsSold);
      }

      // Decrement discount
      if (discount > 0) {
        updates['totalDiscount'] = FieldValue.increment(-discount);
      }

      // Decrement customer count
      updates['customersServed'] = FieldValue.increment(-1);

      await summaryRef.set(updates, SetOptions(merge: true));

      debugPrint('Dashboard summary updated successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onCreditDeleted: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  // ========== CREDIT TO SALE CONVERSION ==========

  /// Updates dashboard when a credit is converted to a sale (fully paid).
  /// Decrements: totalCredit (if not paid), totalMtRemaining
  /// Increments: totalCollection (if not paid)
  /// Only updates if the bill is from today.
  Future<bool> onCreditConvertedToSale({
    required String salesmanName,
    required DateTime date,
    required int amountDue,
    required int cratesDue,
    required bool isPaidBill,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Credit not from today, skipping update',
      );
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onCreditConvertedToSale');
      debugPrint(
        'Amount: $amountDue, Crates: $cratesDue, WasPaid: $isPaidBill',
      );

      final summaryRef = _getSummaryRef(salesmanName, date);
      final Map<String, dynamic> updates = {
        'totalMtRemaining': FieldValue.increment(-cratesDue),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only update credit and collection if bill was NOT already paid
      if (!isPaidBill) {
        updates['totalCollection'] = FieldValue.increment(amountDue);
        updates['totalCredit'] = FieldValue.increment(-amountDue);
      }

      await summaryRef.set(updates, SetOptions(merge: true));

      debugPrint('Dashboard summary updated for credit-to-sale conversion');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onCreditConvertedToSale: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Updates dashboard when a sale is converted to credit (moved back to credit).
  /// Decrements: totalCollection, totalItemsSold
  /// Increments: totalCredit
  /// Only updates if the sale is from today.
  Future<bool> onSaleConvertedToCredit({
    required String salesmanName,
    required DateTime date,
    required int totalAmount,
    required int itemsSold,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Sale not from today, skipping update',
      );
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onSaleConvertedToCredit');
      debugPrint('Amount: $totalAmount, Items: $itemsSold');

      final summaryRef = _getSummaryRef(salesmanName, date);
      await summaryRef.set({
        'totalCollection': FieldValue.increment(-totalAmount),
        'totalItemsSold': FieldValue.increment(-itemsSold),
        'totalCredit': FieldValue.increment(totalAmount),
        'totalMtRemaining': FieldValue.increment(0),
        // customersServed stays the same
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Dashboard summary updated for sale-to-credit conversion');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onSaleConvertedToCredit: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  // ========== PARTIAL PAYMENT OPERATIONS ==========

  /// Updates dashboard when a partial payment is received on a credit.
  /// Increments: totalCollection (cash received)
  /// Decrements: totalCredit (cash received), totalMtRemaining (crates received)
  /// Only updates if the bill is from today.
  Future<bool> onPartialPaymentReceived({
    required String salesmanName,
    required DateTime date,
    int? cashReceived,
    int? cratesReceived,
    required bool isPaidBill,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Credit not from today, skipping update',
      );
      return true;
    }

    // Skip if nothing to update
    if ((cashReceived == null || cashReceived == 0) &&
        (cratesReceived == null || cratesReceived == 0)) {
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onPartialPaymentReceived');
      debugPrint(
        'Cash: $cashReceived, Crates: $cratesReceived, WasPaid: $isPaidBill',
      );

      final summaryRef = _getSummaryRef(salesmanName, date);
      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only update credit and collection if bill was NOT already paid
      if (cashReceived != null && cashReceived > 0 && !isPaidBill) {
        updates['totalCollection'] = FieldValue.increment(cashReceived);
        updates['totalCredit'] = FieldValue.increment(-cashReceived);
      }

      // Always update crates when received
      if (cratesReceived != null && cratesReceived > 0) {
        updates['totalMtRemaining'] = FieldValue.increment(-cratesReceived);
      }

      await summaryRef.set(updates, SetOptions(merge: true));

      debugPrint('Dashboard summary updated for partial payment');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onPartialPaymentReceived: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }
}
