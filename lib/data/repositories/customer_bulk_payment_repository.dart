import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/customer_bulk_payment.dart';
import 'package:flutter/foundation.dart';

/// Repository for storing and retrieving bulk payment records per customer.
/// Path: Bulk Payments/{salesmanName}/customers/{customerKey}
class CustomerBulkPaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Normalizes a customer name for use as a Firestore document key.
  String _customerKey(String customerName) =>
      customerName.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  DocumentReference _docRef(String salesmanName, String customerName) =>
      _firestore
          .collection('Bulk Payments')
          .doc(salesmanName)
          .collection('customers')
          .doc(_customerKey(customerName));

  /// Retrieves bulk payment record for a customer.
  /// Returns null if no record exists yet.
  Future<CustomerBulkPayment?> getBulkPayment({
    required String salesmanName,
    required String customerName,
  }) async {
    try {
      final doc = await _docRef(salesmanName, customerName).get();
      if (!doc.exists) return null;
      return CustomerBulkPayment.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting bulk payment: $e');
      return null;
    }
  }

  /// Adds a new payment entry to the customer's bulk payment record.
  /// Creates the record if it does not exist yet.
  /// Returns true on success, false on failure.
  /// [billAmounts] – optional map of billId→amountDue to store on first call.
  Future<bool> addPaymentEntry({
    required String salesmanName,
    required String customerName,
    required int amount,
    required DateTime date,
    Map<String, int>? billAmounts,
  }) async {
    try {
      final entry = BulkPaymentEntry(date: date, amount: amount);
      final ref = _docRef(salesmanName, customerName);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (doc.exists) {
          final existing = CustomerBulkPayment.fromJson(
            doc.data() as Map<String, dynamic>,
          );
          final updated = existing.copyWith(
            paymentHistory: [...existing.paymentHistory, entry],
            updatedAt: DateTime.now(),
          );
          transaction.update(ref, updated.toJson());
        } else {
          final newRecord = CustomerBulkPayment(
            customerName: customerName,
            paymentHistory: [entry],
            billAmounts: billAmounts ?? {},
            updatedAt: DateTime.now(),
          );
          transaction.set(ref, newRecord.toJson());
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error adding bulk payment entry: $e');
      return false;
    }
  }

  /// Deletes the bulk payment record for a customer (called after full settlement).
  Future<bool> deleteBulkPayment({
    required String salesmanName,
    required String customerName,
  }) async {
    try {
      await _docRef(salesmanName, customerName).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting bulk payment record: $e');
      return false;
    }
  }

  /// Returns the set of customer keys (normalised) that have an active bulk
  /// payment record for the given salesman.  Used by the credit record page to
  /// disable the delete button on individual bills.
  Future<Set<String>> getCustomersWithBulkPayments(String salesmanName) async {
    try {
      final snapshot = await _firestore
          .collection('Bulk Payments')
          .doc(salesmanName)
          .collection('customers')
          .get();
      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('Error fetching customers with bulk payments: $e');
      return {};
    }
  }
}
