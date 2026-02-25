import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/core/utils/date_formatters.dart';
import 'package:ch_atta_traders_billing_application/data/models/cleared_bill.dart';
import 'package:flutter/foundation.dart';

/// Repository for storing and fetching bills that were cleared (fully paid) today
/// but originally belonged to a previous day.
///
/// Firestore path: Cleared Bills/{salesmanName}/{todayDate}/bills/{billId}
class ClearedBillRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a cleared bill record to Firestore.
  /// Called when a previous-day credit bill is fully cleared today.
  /// For partial payments, uses a unique doc ID to allow multiple entries per bill.
  Future<void> saveClearedBill({
    required String salesmanName,
    required ClearedBill clearedBill,
  }) async {
    try {
      final todayFormatted = DateFormatters.formatForFirebase(DateTime.now());

      // For partial payments, append timestamp to avoid overwriting previous entries
      final docId = clearedBill.isPartialPayment
          ? '${clearedBill.billId}_partial_${clearedBill.clearedDate.millisecondsSinceEpoch}'
          : clearedBill.billId;

      await _firestore
          .collection('Cleared Bills')
          .doc(salesmanName)
          .collection(todayFormatted)
          .doc(docId)
          .set(clearedBill.toJson());

      debugPrint(
        'Cleared bill saved: $docId for $salesmanName on $todayFormatted',
      );
    } catch (e) {
      debugPrint('Error saving cleared bill: $e');
      rethrow;
    }
  }

  /// Fetches all cleared bills for a salesman on a specific date.
  /// Defaults to today if no date is provided.
  Future<List<ClearedBill>> getClearedBills({
    required String salesmanName,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final formattedDate = DateFormatters.formatForFirebase(targetDate);

      debugPrint('Fetching cleared bills for $salesmanName on $formattedDate');

      final querySnapshot = await _firestore
          .collection('Cleared Bills')
          .doc(salesmanName)
          .collection(formattedDate)
          .orderBy('clearedDate', descending: true)
          .get();

      final bills = querySnapshot.docs
          .map((doc) => ClearedBill.fromJson(doc.data()))
          .toList();

      debugPrint('Fetched ${bills.length} cleared bills');
      return bills;
    } catch (e) {
      debugPrint('Error fetching cleared bills: $e');
      rethrow;
    }
  }

  /// Deletes all partial payment entries for a specific bill.
  /// Called when a bill is fully cleared so partial entries don't linger.
  Future<void> deletePartialEntries({
    required String salesmanName,
    required String billId,
  }) async {
    try {
      final todayFormatted = DateFormatters.formatForFirebase(DateTime.now());
      final collectionRef = _firestore
          .collection('Cleared Bills')
          .doc(salesmanName)
          .collection(todayFormatted);

      // Query all docs whose ID starts with '{billId}_partial_'
      // Firestore doesn't support prefix queries on doc IDs directly,
      // so we fetch all docs and filter client-side (collection is small per day)
      final snapshot = await collectionRef.get();
      final partialDocs = snapshot.docs.where(
        (doc) => doc.id.startsWith('${billId}_partial_'),
      );

      if (partialDocs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in partialDocs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint(
        'Deleted ${partialDocs.length} partial entries for bill $billId',
      );
    } catch (e) {
      debugPrint('Error deleting partial entries: $e');
      // Non-critical: don't rethrow
    }
  }
}
