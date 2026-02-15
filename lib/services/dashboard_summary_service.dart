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
  /// Uses a transaction to prevent values from going below zero.
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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);

        if (!snapshot.exists) {
          debugPrint(
            'DashboardSummaryService: Summary doc not found, skipping delete update',
          );
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final currentCollection =
            (data['totalCollection'] as num?)?.toInt() ?? 0;
        final currentItemsSold = (data['totalItemsSold'] as num?)?.toInt() ?? 0;
        final currentDiscount = (data['totalDiscount'] as num?)?.toInt() ?? 0;
        final currentCustomers =
            (data['customersServed'] as num?)?.toInt() ?? 0;

        transaction.set(summaryRef, {
          'totalCollection': (currentCollection - totalAmount).clamp(
            0,
            currentCollection,
          ),
          'totalItemsSold': (currentItemsSold - itemsSold).clamp(
            0,
            currentItemsSold,
          ),
          'totalDiscount': (currentDiscount - discount).clamp(
            0,
            currentDiscount,
          ),
          'customersServed': (currentCustomers - 1).clamp(0, currentCustomers),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onSaleDeleted: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  // ========== CREDIT OPERATIONS ==========

  /// Updates dashboard when a new credit is created.
  /// Increments: totalCredit (if not paid), totalCollection (if paid in cash), totalItemsSold, totalMtRemaining, totalDiscount, customersServed
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

    final updates = {
      'totalItemsSold': FieldValue.increment(itemsSold),
      'totalMtRemaining': FieldValue.increment(mtRemaining),
      'totalDiscount': FieldValue.increment(discount),
      'customersServed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // If paid (cash payment with MT tracking), add to totalCollection
    // If not paid (credit payment), add to totalCredit
    if (isPaid) {
      updates['totalCollection'] = FieldValue.increment(creditAmount);
    } else {
      updates['totalCredit'] = FieldValue.increment(creditAmount);
    }

    if (transaction != null) {
      transaction.set(summaryRef, updates, SetOptions(merge: true));
    } else {
      await summaryRef.set(updates, SetOptions(merge: true));
    }
  }

  /// Updates dashboard when a credit is deleted permanently.
  /// Decrements: totalCredit (if not paid), totalItemsSold, totalMtRemaining, totalDiscount, customersServed
  /// Only updates if the credit is from today.
  /// Uses a transaction to prevent values from going below zero.
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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);

        if (!snapshot.exists) {
          debugPrint(
            'DashboardSummaryService: Summary doc not found, skipping credit delete update',
          );
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final Map<String, dynamic> updates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // Decrement credit if bill was not paid (clamped to 0)
        if (amountDue > 0 && !isPaidBill) {
          final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;
          updates['totalCredit'] = (currentCredit - amountDue).clamp(
            0,
            currentCredit,
          );
        }

        // Decrement MT remaining if there were crates due (clamped to 0)
        if (cratesDue > 0) {
          final currentMt = (data['totalMtRemaining'] as num?)?.toInt() ?? 0;
          updates['totalMtRemaining'] = (currentMt - cratesDue).clamp(
            0,
            currentMt,
          );
        }

        // Decrement items sold (clamped to 0)
        if (itemsSold > 0) {
          final currentItems = (data['totalItemsSold'] as num?)?.toInt() ?? 0;
          updates['totalItemsSold'] = (currentItems - itemsSold).clamp(
            0,
            currentItems,
          );
        }

        // Decrement discount (clamped to 0)
        if (discount > 0) {
          final currentDiscount = (data['totalDiscount'] as num?)?.toInt() ?? 0;
          updates['totalDiscount'] = (currentDiscount - discount).clamp(
            0,
            currentDiscount,
          );
        }

        // Decrement customer count (clamped to 0)
        final currentCustomers =
            (data['customersServed'] as num?)?.toInt() ?? 0;
        updates['customersServed'] = (currentCustomers - 1).clamp(
          0,
          currentCustomers,
        );

        transaction.set(summaryRef, updates, SetOptions(merge: true));
      });

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
  /// Uses a transaction to prevent values from going below zero.
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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};

        final Map<String, dynamic> updates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // Decrement MT remaining (clamped to 0)
        final currentMt = (data['totalMtRemaining'] as num?)?.toInt() ?? 0;
        updates['totalMtRemaining'] = (currentMt - cratesDue).clamp(
          0,
          currentMt,
        );

        // Only update credit and collection if bill was NOT already paid
        if (!isPaidBill) {
          final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;
          updates['totalCredit'] = (currentCredit - amountDue).clamp(
            0,
            currentCredit,
          );
          final currentCollection =
              (data['totalCollection'] as num?)?.toInt() ?? 0;
          updates['totalCollection'] = currentCollection + amountDue;
        }

        transaction.set(summaryRef, updates, SetOptions(merge: true));
      });

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
  /// Uses a transaction to prevent values from going below zero.
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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};

        final currentCollection =
            (data['totalCollection'] as num?)?.toInt() ?? 0;
        final currentItemsSold = (data['totalItemsSold'] as num?)?.toInt() ?? 0;
        final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;

        transaction.set(summaryRef, {
          'totalCollection': (currentCollection - totalAmount).clamp(
            0,
            currentCollection,
          ),
          'totalItemsSold': (currentItemsSold - itemsSold).clamp(
            0,
            currentItemsSold,
          ),
          'totalCredit': currentCredit + totalAmount,
          'totalMtRemaining': FieldValue.increment(0),
          // customersServed stays the same
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

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
  /// Uses a transaction to prevent values from going below zero.
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

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};

        final Map<String, dynamic> updates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // Only update credit and collection if bill was NOT already paid
        if (cashReceived != null && cashReceived > 0 && !isPaidBill) {
          final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;
          final currentCollection =
              (data['totalCollection'] as num?)?.toInt() ?? 0;
          updates['totalCredit'] = (currentCredit - cashReceived).clamp(
            0,
            currentCredit,
          );
          updates['totalCollection'] = currentCollection + cashReceived;
        }

        // Decrement crates when received (clamped to 0)
        if (cratesReceived != null && cratesReceived > 0) {
          final currentMt = (data['totalMtRemaining'] as num?)?.toInt() ?? 0;
          updates['totalMtRemaining'] = (currentMt - cratesReceived).clamp(
            0,
            currentMt,
          );
        }

        transaction.set(summaryRef, updates, SetOptions(merge: true));
      });

      debugPrint('Dashboard summary updated for partial payment');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onPartialPaymentReceived: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  // ========== PREVIOUS DAY COLLECTION OPERATIONS ==========

  /// Updates today's dashboard with previous day collection data.
  /// This is called when a credit bill from a previous day is paid/updated.
  /// Increments: previousDayCash (cash received), previousDayMt (crates received)
  /// Updates are always made to TODAY's summary document.
  Future<bool> onPreviousDayCollectionReceived({
    required String salesmanName,
    int? cashReceived,
    int? cratesReceived,
  }) async {
    // Skip if nothing to update
    if ((cashReceived == null || cashReceived == 0) &&
        (cratesReceived == null || cratesReceived == 0)) {
      return true;
    }

    try {
      debugPrint('DashboardSummaryService: onPreviousDayCollectionReceived');
      debugPrint('Cash: $cashReceived, Crates: $cratesReceived');

      // Always update TODAY's summary document
      final today = DateTime.now();
      final summaryRef = _getSummaryRef(salesmanName, today);

      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Increment previous day cash
      if (cashReceived != null && cashReceived > 0) {
        updates['previousDayCash'] = FieldValue.increment(cashReceived);
      }

      // Increment previous day MT (crates)
      if (cratesReceived != null && cratesReceived > 0) {
        updates['previousDayMt'] = FieldValue.increment(cratesReceived);
      }

      await summaryRef.set(updates, SetOptions(merge: true));

      debugPrint('Dashboard summary updated for previous day collection');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in onPreviousDayCollectionReceived: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }
}
