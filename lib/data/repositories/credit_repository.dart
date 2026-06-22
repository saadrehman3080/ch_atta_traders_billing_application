import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/services/dashboard_summary_service.dart';
import 'package:flutter/foundation.dart';

class CreditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DashboardSummaryService _dashboardService = DashboardSummaryService();

  /// Saves a credit transaction to Firestore and updates the dashboard summary
  /// Path: Credit History/{salesmanName}/bills/{billId}
  /// Summary Path: Dashboard Summary/{salesmanName}/{dd-MMM-yyyy}/summary
  Future<void> saveCredit(CreditHistory credit, String salesmanName) async {
    try {
      debugPrint('Saving credit to Firestore...');
      debugPrint('Salesman: $salesmanName');
      debugPrint('Bill ID: ${credit.billId}');

      // Calculate totals for dashboard
      final itemsSold = credit.products.fold<int>(
        0,
        (total, product) => total + product.quantity,
      );

      // Use cratesDue directly from credit:
      // - MT field not filled (empty): cratesDue = 0 (don't track MT)
      // - MT field filled with 0: cratesDue = total - 0 = all crates remaining
      // - MT field filled with value: cratesDue = total - collected = remaining crates
      final mtRemaining = credit.cratesDue;

      // Use transaction to atomically update both credit and dashboard summary
      await _firestore.runTransaction((transaction) async {
        // Reference to the credit document (in Credit History)
        final creditRef = _firestore
            .collection('Credit History')
            .doc(salesmanName)
            .collection('bills')
            .doc(credit.billId);

        // Save the credit document — idempotent: safe to retry.
        transaction.set(creditRef, credit.toJson(), SetOptions(merge: true));

        // Update dashboard summary using centralized service
        await _dashboardService.onCreditCreated(
          salesmanName: salesmanName,
          date: credit.date,
          creditAmount: credit.amountDue,
          itemsSold: itemsSold,
          mtRemaining: mtRemaining,
          discount: credit.discount,
          isPaid: credit.isPaid,
          partialPaymentAmount: credit.totalPartialPaymentAmount,
          transaction: transaction,
        );
      });

      debugPrint('Credit and dashboard summary saved successfully!');
    } catch (e) {
      debugPrint('Error saving credit: $e');
      rethrow;
    }
  }

  /// Reads a specific credit transaction from Firestore
  /// Path: Credit History/{salesmanName}/bills/{billId}
  Future<CreditHistory?> getCreditById({
    required String salesmanName,
    required String billId,
  }) async {
    try {
      debugPrint('Fetching credit from Firestore...');
      debugPrint('Salesman: $salesmanName');
      debugPrint('Bill ID: $billId');

      final docSnapshot = await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection('bills')
          .doc(billId)
          .get();

      if (!docSnapshot.exists) {
        debugPrint('Credit record not found');
        return null;
      }

      debugPrint('Credit fetched successfully!');
      return CreditHistory.fromJson(docSnapshot.data()!);
    } catch (e) {
      debugPrint('Error fetching credit: $e');
      rethrow;
    }
  }

  /// Updates an existing credit transaction
  /// Path: Credit History/{salesmanName}/bills/{billId}
  Future<void> updateCredit({
    required String salesmanName,
    required CreditHistory credit,
  }) async {
    try {
      debugPrint('Updating credit in Firestore...');

      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection('bills')
          .doc(credit.billId)
          .update(credit.toJson());

      debugPrint('Credit updated successfully!');
    } catch (e) {
      debugPrint('Error updating credit: $e');
      rethrow;
    }
  }

  /// Deletes a credit transaction
  /// Path: Credit History/{salesmanName}/bills/{billId}
  Future<void> deleteCredit({
    required String salesmanName,
    required String billId,
  }) async {
    try {
      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection('bills')
          .doc(billId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Saves a credit record to delete history
  /// Path: Deleted History/{salesmanName}/{date}/{billId}
  Future<void> saveCreditToDeleteHistory({
    required String path,
    required CreditHistory credit,
  }) async {
    try {
      final creditData = {
        'billId': credit.billId,
        'customerName': credit.customerName,
        'date': Timestamp.fromDate(credit.date),
        'products': credit.products.map((p) => p.toJson()).toList(),
        'discount': credit.discount,
        'amountDue': credit.amountDue,
        'cratesDue': credit.cratesDue,
        'isPaid': credit.isPaid,
        'deletedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.doc(path).set(creditData);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates only the amountDue and cratesDue fields of a credit record
  /// Also updates isPaid status when explicitly provided
  /// Path: Credit History/{salesmanName}/bills/{billId}
  Future<void> updateCreditBalance({
    required String salesmanName,
    required String billId,
    int? newAmountDue,
    int? newCratesDue,
    bool? isPaid,
    bool? isRecordUpdated,
    PartialPayment? newPartialPayment,
  }) async {
    try {
      debugPrint('Updating credit balance in Firestore...');
      debugPrint('Salesman: $salesmanName');
      debugPrint('Bill ID: $billId');

      final Map<String, dynamic> updates = {};

      if (newAmountDue != null) {
        updates['amountDue'] = newAmountDue;
        debugPrint('New amountDue: $newAmountDue');
      }

      if (newCratesDue != null) {
        updates['cratesDue'] = newCratesDue;
        debugPrint('New cratesDue: $newCratesDue');
      }

      if (isPaid != null) {
        updates['isPaid'] = isPaid;
        debugPrint('New isPaid: $isPaid');
      }

      // Append partial payment to the existing list
      if (newPartialPayment != null) {
        updates['partialPayments'] = FieldValue.arrayUnion([
          newPartialPayment.toJson(),
        ]);
        debugPrint('Adding partial payment: ${newPartialPayment.amount}');
      }

      if (updates.isEmpty) {
        debugPrint('No updates to apply');
        return;
      }

      // When updating, set isRecordUpdated flag. If caller provided a value, use it;
      // otherwise default to true when there are updates.
      if (isRecordUpdated != null) {
        updates['isRecordUpdated'] = isRecordUpdated;
      } else if (updates.isNotEmpty) {
        updates['isRecordUpdated'] = true;
      }

      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection('bills')
          .doc(billId)
          .update(updates);

      debugPrint('Credit balance updated successfully!');
    } catch (e) {
      debugPrint('Error updating credit balance: $e');
      rethrow;
    }
  }

  /// Fetches all credit records for a salesman
  /// Path: Credit History/{salesmanName}/bills
  ///
  /// Returns a list of all credit records, sorted by date descending.
  Future<List<CreditHistory>> getAllCreditsForSalesman({
    required String salesmanName,
  }) async {
    try {
      debugPrint('Fetching all credits for salesman: $salesmanName');

      final querySnapshot = await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection('bills')
          .orderBy('date', descending: true)
          .get();

      final credits = querySnapshot.docs
          .map((doc) => CreditHistory.fromJson(doc.data()))
          .toList();

      debugPrint('Fetched ${credits.length} credit records');
      return credits;
    } catch (e) {
      debugPrint('Error fetching credits: $e');
      rethrow;
    }
  }
}
