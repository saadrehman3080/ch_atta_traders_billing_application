import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:intl/intl.dart';

class CreditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a credit transaction to Firestore
  /// Path: Credit History/{salesmanName}/{dd-MMM-yyyy}/{billId}
  Future<void> saveCredit(CreditHistory credit, String salesmanName) async {
    try {
      // Format date as dd-MMM-yyyy (e.g., 01-Jan-2026)
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final formattedDate = dateFormat.format(credit.date);

      print('Saving credit to Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $formattedDate');
      print('Bill ID: ${credit.billId}');

      // Save to Credit History/{salesmanName}/{date}/{billId}
      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc(credit.billId)
          .set(credit.toJson());

      print('Credit saved successfully!');
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
      print('Deleting credit from Firestore...');

      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(date)
          .doc(billId)
          .delete();

      print('Credit deleted successfully!');
    } catch (e) {
      print('Error deleting credit: $e');
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
  /// This method uses optimized parallel queries with batching to fetch
  /// credit records efficiently. It queries multiple dates concurrently
  /// and implements early termination when no more data is found.
  ///
  /// [salesmanName] - The name of the salesman
  /// [daysToLookBack] - Number of days to look back (default: 30 days)
  /// [batchSize] - Number of concurrent queries per batch (default: 10)
  /// [maxEmptyDays] - Stop after this many consecutive empty days (default: 14)
  ///
  /// Returns a list of all credit records found, sorted by date descending.
  Future<List<CreditHistory>> getAllCreditsForSalesman({
    required String salesmanName,
    int daysToLookBack = 30,
    int batchSize = 10,
    int maxEmptyDays = 14,
  }) async {
    try {
      print('Fetching all credits for salesman: $salesmanName');
      print('Looking back $daysToLookBack days with batch size: $batchSize');

      final dateFormat = DateFormat('dd-MMM-yyyy');
      final now = DateTime.now();
      List<CreditHistory> allCredits = [];
      int consecutiveEmptyDays = 0;

      // Process dates in batches for parallel queries
      for (int startDay = 0; startDay < daysToLookBack; startDay += batchSize) {
        // Early termination if we've seen too many consecutive empty days
        if (consecutiveEmptyDays >= maxEmptyDays) {
          print('Stopping early: $consecutiveEmptyDays consecutive empty days');
          break;
        }

        final endDay = (startDay + batchSize > daysToLookBack)
            ? daysToLookBack
            : startDay + batchSize;

        // Create batch of date queries
        List<Future<QuerySnapshot>> batchQueries = [];
        List<String> batchDates = [];

        for (int i = startDay; i < endDay; i++) {
          final date = now.subtract(Duration(days: i));
          final formattedDate = dateFormat.format(date);
          batchDates.add(formattedDate);

          batchQueries.add(
            _firestore
                .collection('Credit History')
                .doc(salesmanName)
                .collection(formattedDate)
                .get(),
          );
        }

        // Execute all queries in this batch concurrently
        try {
          final results = await Future.wait(
            batchQueries,
            eagerError: false, // Continue even if some queries fail
          );

          // Process results
          bool foundDataInBatch = false;
          for (int i = 0; i < results.length; i++) {
            try {
              final querySnapshot = results[i];
              if (querySnapshot.docs.isNotEmpty) {
                foundDataInBatch = true;
                consecutiveEmptyDays = 0;

                final credits = querySnapshot.docs
                    .map((doc) {
                      try {
                        final data = doc.data();
                        if (data == null) return null;
                        return CreditHistory.fromJson(
                          data as Map<String, dynamic>,
                        );
                      } catch (e) {
                        print('Error parsing document ${doc.id}: $e');
                        return null;
                      }
                    })
                    .whereType<CreditHistory>() // Filter out nulls
                    .toList();

                if (credits.isNotEmpty) {
                  allCredits.addAll(credits);
                  print('Found ${credits.length} records for ${batchDates[i]}');
                }
              } else {
                consecutiveEmptyDays++;
              }
            } catch (e) {
              print('Error processing result for ${batchDates[i]}: $e');
              consecutiveEmptyDays++;
            }
          }

          // Reset counter if we found data in this batch
          if (foundDataInBatch) {
            consecutiveEmptyDays = 0;
          }
        } catch (e) {
          print('Error in batch query: $e');
        }

        // Small delay between batches to avoid overwhelming Firestore
        if (startDay + batchSize < daysToLookBack) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Sort by date descending (most recent first)
      allCredits.sort((a, b) => b.date.compareTo(a.date));

      print('Successfully fetched ${allCredits.length} total credit records');
      return allCredits;
    } catch (e) {
      print('Error fetching all credits: $e');
      rethrow;
    }
  }
}
