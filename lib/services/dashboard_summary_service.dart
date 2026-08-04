import 'package:ch_atta_traders_billing_application/core/utils/date_formatters.dart';
import 'package:ch_atta_traders_billing_application/data/models/offline_dashboard_payload.dart';
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

  /// Applies a queued offline dashboard payload exactly once per [billId].
  ///
  /// Idempotency is enforced by creating a marker document at:
  /// Dashboard Summary/{salesman}/{date}/summary/appliedOfflineBills/{billId}
  /// and skipping increments when the marker already exists.
  Future<void> applyOfflineDashboardPayload({
    required OfflineDashboardPayload payload,
  }) async {
    final summaryRef = _getSummaryRef(payload.salesmanIdentifier, payload.date);
    final markerRef = summaryRef
        .collection('appliedOfflineBills')
        .doc(payload.billId);

    await _firestore.runTransaction((transaction) async {
      final markerSnapshot = await transaction.get(markerRef);
      if (markerSnapshot.exists) {
        debugPrint(
          'DashboardSummaryService: payload already applied for ${payload.billId}',
        );
        return;
      }

      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (payload.totalCollectionDelta != 0) {
        updates['totalCollection'] = FieldValue.increment(
          payload.totalCollectionDelta,
        );
      }
      if (payload.totalItemsSoldDelta != 0) {
        updates['totalItemsSold'] = FieldValue.increment(
          payload.totalItemsSoldDelta,
        );
      }
      if (payload.totalMtRemainingDelta != 0) {
        updates['totalMtRemaining'] = FieldValue.increment(
          payload.totalMtRemainingDelta,
        );
      }
      if (payload.totalCreditDelta != 0) {
        updates['totalCredit'] = FieldValue.increment(payload.totalCreditDelta);
      }
      if (payload.totalDiscountDelta != 0) {
        updates['totalDiscount'] = FieldValue.increment(
          payload.totalDiscountDelta,
        );
      }
      if (payload.customersServedDelta != 0) {
        updates['customersServed'] = FieldValue.increment(
          payload.customersServedDelta,
        );
      }
      if (payload.previousDayCashDelta != 0) {
        updates['previousDayCash'] = FieldValue.increment(
          payload.previousDayCashDelta,
        );
      }
      if (payload.previousDayMtDelta != 0) {
        updates['previousDayMt'] = FieldValue.increment(
          payload.previousDayMtDelta,
        );
      }

      transaction.set(summaryRef, updates, SetOptions(merge: true));
      transaction.set(markerRef, {
        'billId': payload.billId,
        'createdAt': Timestamp.fromDate(payload.createdAt),
        'appliedAt': FieldValue.serverTimestamp(),
        'schemaVersion': payload.schemaVersion,
      }, SetOptions(merge: true));
    });
  }

  /// Applies a dashboard mutation exactly once per [actionId].
  ///
  /// Manual credit/sale actions (delete, convert-to-sale, partial payment)
  /// are performed as several separate, non-transactional Firestore calls
  /// (save/convert doc, update dashboard, delete/update doc). If any step
  /// after the dashboard update fails and the user retries the whole
  /// operation, the dashboard delta would previously be re-applied even
  /// though the underlying bill data only changed once - causing the
  /// dashboard totals to drift from the real bill list.
  ///
  /// Idempotency is enforced by a marker document at:
  /// Dashboard Summary/{salesman}/{date}/summary/processedActions/{actionId}
  Future<bool> _applyIdempotentUpdate({
    required String salesmanName,
    required DateTime date,
    required String actionId,
    required Map<String, dynamic> Function(Map<String, dynamic> currentData)
    buildUpdates,
  }) async {
    final summaryRef = _getSummaryRef(salesmanName, date);
    final markerRef = summaryRef.collection('processedActions').doc(actionId);

    try {
      await _firestore.runTransaction((transaction) async {
        final markerSnapshot = await transaction.get(markerRef);
        if (markerSnapshot.exists) {
          debugPrint(
            'DashboardSummaryService: action already applied: $actionId',
          );
          return;
        }

        final summarySnapshot = await transaction.get(summaryRef);
        final data = summarySnapshot.data() as Map<String, dynamic>? ?? {};

        final updates = buildUpdates(data);
        updates['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(summaryRef, updates, SetOptions(merge: true));
        transaction.set(markerRef, {
          'actionId': actionId,
          'appliedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error applying dashboard action $actionId: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
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
  /// Idempotent per [billId] so a retry after a later step fails (e.g. the
  /// actual sale document delete) does not decrement the dashboard twice.
  Future<bool> onSaleDeleted({
    required String salesmanName,
    required DateTime date,
    required String billId,
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

    debugPrint('DashboardSummaryService: onSaleDeleted');
    debugPrint('Amount: $totalAmount, Items: $itemsSold, Discount: $discount');

    return _applyIdempotentUpdate(
      salesmanName: salesmanName,
      date: date,
      actionId: 'saleDelete_$billId',
      buildUpdates: (data) {
        final currentCollection =
            (data['totalCollection'] as num?)?.toInt() ?? 0;
        final currentItemsSold = (data['totalItemsSold'] as num?)?.toInt() ?? 0;
        final currentDiscount = (data['totalDiscount'] as num?)?.toInt() ?? 0;
        final currentCustomers =
            (data['customersServed'] as num?)?.toInt() ?? 0;

        return {
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
        };
      },
    );
  }

  // ========== CREDIT OPERATIONS ==========

  /// Updates dashboard when a new credit is created.
  /// Increments: totalCredit (if not paid), totalCollection (if paid in cash or partial payment received),
  /// totalItemsSold, totalMtRemaining, totalDiscount, customersServed
  Future<void> onCreditCreated({
    required String salesmanName,
    required DateTime date,
    required int creditAmount,
    required int itemsSold,
    required int mtRemaining,
    required int discount,
    required bool isPaid,
    int partialPaymentAmount = 0,
    Transaction? transaction,
  }) async {
    debugPrint('DashboardSummaryService: onCreditCreated');
    debugPrint(
      'Credit: $creditAmount, Items: $itemsSold, MT: $mtRemaining, Discount: $discount, IsPaid: $isPaid, PartialPayment: $partialPaymentAmount',
    );

    final summaryRef = _getSummaryRef(salesmanName, date);

    final updates = {
      'totalItemsSold': FieldValue.increment(itemsSold),
      'totalMtRemaining': FieldValue.increment(mtRemaining),
      'totalDiscount': FieldValue.increment(discount),
      'customersServed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // If paid (cash payment with MT tracking), add full amount to totalCollection
    // If not paid (credit payment), add remaining to totalCredit
    //   and add any partial payment received to totalCollection
    if (isPaid) {
      updates['totalCollection'] = FieldValue.increment(creditAmount);
    } else {
      updates['totalCredit'] = FieldValue.increment(creditAmount);
      if (partialPaymentAmount > 0) {
        updates['totalCollection'] = FieldValue.increment(partialPaymentAmount);
      }
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
  /// Idempotent per [billId] so a retry after a later step fails (e.g. the
  /// actual credit document delete) does not decrement the dashboard twice.
  Future<bool> onCreditDeleted({
    required String salesmanName,
    required DateTime date,
    required String billId,
    required int amountDue,
    required int cratesDue,
    required int itemsSold,
    required int discount,
    required bool isPaidBill,
    int partialPaymentTotal = 0,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Credit not from today, skipping update',
      );
      return true;
    }

    debugPrint('DashboardSummaryService: onCreditDeleted');
    debugPrint(
      'Amount: $amountDue, Crates: $cratesDue, Items: $itemsSold, Discount: $discount, WasPaid: $isPaidBill, PartialPaymentTotal: $partialPaymentTotal',
    );

    return _applyIdempotentUpdate(
      salesmanName: salesmanName,
      date: date,
      actionId: 'creditDelete_$billId',
      buildUpdates: (data) {
        final Map<String, dynamic> updates = {};

        // Decrement credit if bill was not paid (clamped to 0)
        if (amountDue > 0 && !isPaidBill) {
          final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;
          updates['totalCredit'] = (currentCredit - amountDue).clamp(
            0,
            currentCredit,
          );
        }

        // Reverse totalCollection:
        // - For paid bills (cash+MT): full amountDue was in collection
        // - For unpaid bills (credit): partial payments were in collection
        int collectionToReverse = 0;
        if (isPaidBill) {
          collectionToReverse = amountDue;
        } else if (partialPaymentTotal > 0) {
          collectionToReverse = partialPaymentTotal;
        }
        if (collectionToReverse > 0) {
          final currentCollection =
              (data['totalCollection'] as num?)?.toInt() ?? 0;
          updates['totalCollection'] = (currentCollection - collectionToReverse)
              .clamp(0, currentCollection);
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

        return updates;
      },
    );
  }

  // ========== CREDIT TO SALE CONVERSION ==========

  /// Updates dashboard when a credit is converted to a sale (fully paid).
  /// Decrements: totalCredit (if not paid), totalMtRemaining
  /// Increments: totalCollection (if not paid)
  /// Only updates if the bill is from today.
  /// Idempotent per [billId] so a retry after a later step fails (e.g. the
  /// credit document delete) does not apply the conversion twice.
  Future<bool> onCreditConvertedToSale({
    required String salesmanName,
    required DateTime date,
    required String billId,
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

    debugPrint('DashboardSummaryService: onCreditConvertedToSale');
    debugPrint('Amount: $amountDue, Crates: $cratesDue, WasPaid: $isPaidBill');

    return _applyIdempotentUpdate(
      salesmanName: salesmanName,
      date: date,
      actionId: 'creditConvert_$billId',
      buildUpdates: (data) {
        final Map<String, dynamic> updates = {};

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

        return updates;
      },
    );
  }

  /// Updates dashboard when a sale is converted to credit (moved back to credit).
  /// Decrements: totalCollection, totalItemsSold
  /// Increments: totalCredit
  /// Only updates if the sale is from today.
  /// Idempotent per [billId] so a retry after a later step fails (e.g. the
  /// sale document delete) does not apply the conversion twice.
  Future<bool> onSaleConvertedToCredit({
    required String salesmanName,
    required DateTime date,
    required String billId,
    required int totalAmount,
    required int itemsSold,
  }) async {
    if (!_isToday(date)) {
      debugPrint(
        'DashboardSummaryService: Sale not from today, skipping update',
      );
      return true;
    }

    debugPrint('DashboardSummaryService: onSaleConvertedToCredit');
    debugPrint('Amount: $totalAmount, Items: $itemsSold');

    return _applyIdempotentUpdate(
      salesmanName: salesmanName,
      date: date,
      actionId: 'saleToCredit_$billId',
      buildUpdates: (data) {
        final currentCollection =
            (data['totalCollection'] as num?)?.toInt() ?? 0;
        final currentItemsSold = (data['totalItemsSold'] as num?)?.toInt() ?? 0;
        final currentCredit = (data['totalCredit'] as num?)?.toInt() ?? 0;

        return {
          'totalCollection': (currentCollection - totalAmount).clamp(
            0,
            currentCollection,
          ),
          'totalItemsSold': (currentItemsSold - itemsSold).clamp(
            0,
            currentItemsSold,
          ),
          'totalCredit': currentCredit + totalAmount,
        };
      },
    );
  }

  // ========== PARTIAL PAYMENT OPERATIONS ==========

  /// Updates dashboard when a partial payment is received on a credit.
  /// Increments: totalCollection (cash received)
  /// Decrements: totalCredit (cash received), totalMtRemaining (crates received)
  /// Only updates if the bill is from today.
  ///
  /// Idempotent per bill+[previousAmountDue]/[previousCratesDue] (the balance
  /// the bill had *before* this payment). A retry of the same failed payment
  /// attempt targets the same "before" balance and is skipped; a later,
  /// genuinely new partial payment on the same bill has a different "before"
  /// balance and is applied normally.
  Future<bool> onPartialPaymentReceived({
    required String salesmanName,
    required DateTime date,
    required String billId,
    required int previousAmountDue,
    required int previousCratesDue,
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

    debugPrint('DashboardSummaryService: onPartialPaymentReceived');
    debugPrint(
      'Cash: $cashReceived, Crates: $cratesReceived, WasPaid: $isPaidBill',
    );

    return _applyIdempotentUpdate(
      salesmanName: salesmanName,
      date: date,
      actionId:
          'partialPayment_${billId}_from${previousAmountDue}_$previousCratesDue',
      buildUpdates: (data) {
        final Map<String, dynamic> updates = {};

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

        return updates;
      },
    );
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
