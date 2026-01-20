import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/services/dashboard_summary_service.dart';
import 'package:intl/intl.dart';

class CreditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DashboardSummaryService _dashboardService = DashboardSummaryService();

  /// Saves a credit transaction to Firestore and updates the dashboard summary
  /// Path: Credit History/{salesmanName}/{dd-MMM-yyyy}/{billId}
  /// Summary Path: Dashboard Summary/{salesmanName}/{dd-MMM-yyyy}/summary
  Future<void> saveCredit(CreditHistory credit, String salesmanName) async {
    try {
      // Format date as dd-MMM-yyyy (e.g., 01-Jan-2026)
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final formattedDate = dateFormat.format(credit.date);

      print('Saving credit to Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $formattedDate');
      print('Bill ID: ${credit.billId}');

      // Calculate totals for dashboard
      final itemsSold = credit.products.fold<int>(
        0,
        (sum, product) => sum + product.quantity,
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
            .collection(formattedDate)
            .doc(credit.billId);

        // Save the credit document
        transaction.set(creditRef, credit.toJson());

        // Update dashboard summary using centralized service
        await _dashboardService.onCreditCreated(
          salesmanName: salesmanName,
          date: credit.date,
          creditAmount: credit.amountDue,
          itemsSold: itemsSold,
          mtRemaining: mtRemaining,
          discount: credit.discount,
          isPaid: credit.isPaid,
          transaction: transaction,
        );
      });

      print('Credit and dashboard summary saved successfully!');
    } catch (e) {
      print('Error saving credit: $e');
      rethrow;
    }
  }

  /// Reads a specific credit transaction from Firestore
  /// Path: Credit History/{salesmanName}/{dd-MMM-yyyy}/{billId}
  Future<CreditHistory?> getCreditById({
    required String salesmanName,
    required String date,
    required String billId,
  }) async {
    try {
      print('Fetching credit from Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $date');
      print('Bill ID: $billId');

      final docSnapshot = await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
          .doc(billId)
          .get();

      if (!docSnapshot.exists) {
        print('Credit record not found');
        return null;
      }

      print('Credit fetched successfully!');
      return CreditHistory.fromJson(docSnapshot.data()!);
    } catch (e) {
      print('Error fetching credit: $e');
      rethrow;
    }
  }

  /// Reads all credit transactions for a specific salesman and date
  /// Path: Credit History/{salesmanName}/{dd-MMM-yyyy}
  Future<List<CreditHistory>> getCreditsByDate({
    required String salesmanName,
    required String date,
  }) async {
    try {
      print('Fetching credits from Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $date');

      final querySnapshot = await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No credit records found');
        return [];
      }

      print('Fetched ${querySnapshot.docs.length} credit records');
      return querySnapshot.docs
          .map((doc) => CreditHistory.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching credits: $e');
      rethrow;
    }
  }

  /// Reads all credit transactions for a specific salesman across multiple dates
  /// Note: This requires you to provide a list of dates to query
  /// Path: Credit History/{salesmanName}/{dates}
  Future<List<CreditHistory>> getAllCreditsBySalesman({
    required String salesmanName,
    required List<String> dates,
  }) async {
    try {
      print('Fetching all credits for salesman: $salesmanName');
      print('Dates to query: $dates');

      List<CreditHistory> allCredits = [];

      // Query each date collection
      for (var date in dates) {
        final querySnapshot = await _firestore
            .collection('Credit History')
            .doc(salesmanName)
            .collection(date)
            .get();

        final credits = querySnapshot.docs
            .map((doc) => CreditHistory.fromJson(doc.data()))
            .toList();
        allCredits.addAll(credits);
      }

      print('Fetched ${allCredits.length} total credit records');
      return allCredits;
    } catch (e) {
      print('Error fetching all credits: $e');
      rethrow;
    }
  }

  /// Updates an existing credit transaction
  Future<void> updateCredit({
    required String salesmanName,
    required String date,
    required CreditHistory credit,
  }) async {
    try {
      print('Updating credit in Firestore...');

      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
          .doc(credit.billId)
          .update(credit.toJson());

      print('Credit updated successfully!');
    } catch (e) {
      print('Error updating credit: $e');
      rethrow;
    }
  }

  /// Deletes a credit transaction
  Future<void> deleteCredit({
    required String salesmanName,
    required String date,
    required String billId,
  }) async {
    try {
      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
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
  Future<void> updateCreditBalance({
    required String salesmanName,
    required String date,
    required String billId,
    int? newAmountDue,
    int? newCratesDue,
    bool? isPaid,
  }) async {
    try {
      print('Updating credit balance in Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $date');
      print('Bill ID: $billId');

      final Map<String, dynamic> updates = {};

      if (newAmountDue != null) {
        updates['amountDue'] = newAmountDue;
        print('New amountDue: $newAmountDue');
      }

      if (newCratesDue != null) {
        updates['cratesDue'] = newCratesDue;
        print('New cratesDue: $newCratesDue');
      }

      if (isPaid != null) {
        updates['isPaid'] = isPaid;
        print('New isPaid: $isPaid');
      }

      if (updates.isEmpty) {
        print('No updates to apply');
        return;
      }

      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
          .doc(billId)
          .update(updates);

      print('Credit balance updated successfully!');
    } catch (e) {
      print('Error updating credit balance: $e');
      rethrow;
    }
  }

  /// Fetches all credit records for a salesman across all dates
  ///
  /// This method uses a two-step optimized approach:
  /// 1. First, gets metadata (list of date subcollections) with a minimal query
  /// 2. Then, fetches only existing date collections in parallel
  ///
  /// [salesmanName] - The name of the salesman
  /// [daysToLookBack] - Number of days to look back (default: 365 days)
  ///
  /// Returns a list of all credit records found, sorted by date descending.
  Future<List<CreditHistory>> getAllCreditsForSalesman({
    required String salesmanName,
    int daysToLookBack = 14,
  }) async {
    try {
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final now = DateTime.now();

      // Step 1: Get metadata - check which date subcollections exist
      // We do this by querying each collection but only checking if it's empty
      final existingDates = <String>[];
      final metadataCheckFutures = <Future<void>>[];

      for (int i = 0; i < daysToLookBack; i++) {
        final date = now.subtract(Duration(days: i));
        final formattedDate = dateFormat.format(date);

        metadataCheckFutures.add(
          _firestore
              .collection('Credit History')
              .doc(salesmanName)
              .collection(formattedDate)
              .limit(1)
              .get()
              .then((snapshot) {
                if (snapshot.docs.isNotEmpty) {
                  existingDates.add(formattedDate);
                }
              })
              .catchError((_) {
                // Silently skip failed checks
              }),
        );
      }

      // Execute all metadata checks in parallel
      await Future.wait(metadataCheckFutures, eagerError: false);

      // Step 2: Fetch full data only from existing collections
      final dataQueries = existingDates.map((date) {
        return _firestore
            .collection('Credit History')
            .doc(salesmanName)
            .collection(date)
            .get();
      }).toList();

      // Execute all data queries in parallel
      final results = await Future.wait(dataQueries, eagerError: false);

      // Step 3: Process all results in parallel
      final List<CreditHistory> allCredits = [];

      for (final querySnapshot in results) {
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            allCredits.add(CreditHistory.fromJson(data));
          } catch (e) {
            // Skip invalid documents silently
          }
        }
      }

      // Sort by date descending (most recent first)
      allCredits.sort((a, b) => b.date.compareTo(a.date));

      return allCredits;
    } catch (e) {
      rethrow;
    }
  }
}
