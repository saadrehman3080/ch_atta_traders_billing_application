import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Repository for fetching dashboard summary data from Firestore.
///
/// This class fetches pre-aggregated summary document from the
/// centralized Dashboard Summary collection for O(1) dashboard reads.
class DashboardRepository {
  final FirebaseFirestore _firestore;

  DashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches dashboard data for a specific date.
  ///
  /// Reads single summary document:
  /// Dashboard Summary/{salesmanName}/{formattedDate}/summary
  ///
  /// [salesmanName] - The name of the salesman
  /// [date] - The date to fetch data for (defaults to today)
  ///
  /// Returns [DashboardData] from the summary document.
  Future<DashboardData> fetchDashboardData({
    required String salesmanName,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final formattedDate = DateFormat('dd-MMM-yyyy').format(targetDate);

      debugPrint('Fetching dashboard data for $formattedDate...');

      // Fetch the centralized summary document
      final docSnapshot = await _firestore
          .collection('Dashboard Summary')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc('summary')
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        debugPrint('No dashboard summary found for $formattedDate');
        return _emptyDashboardData();
      }

      final dashboardData = DashboardData.fromJson(docSnapshot.data()!);

      debugPrint('Dashboard data fetched successfully');
      debugPrint('Total Collection: ${dashboardData.totalCollection}');
      debugPrint('Total Credit: ${dashboardData.totalCredit}');
      debugPrint('Customers Served: ${dashboardData.customersServed}');

      return dashboardData;
    } catch (e, stackTrace) {
      debugPrint('Error fetching dashboard data: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Returns empty dashboard data (all zeros)
  DashboardData _emptyDashboardData() {
    return DashboardData(
      totalCollection: 0,
      totalItemsSold: 0,
      totalMtRemaining: 0,
      totalCredit: 0,
      totalDiscount: 0,
      customersServed: 0,
    );
  }

  /// Updates dashboard summary when converting a credit bill to sale
  /// This adjusts the summary by:
  /// - Subtracting MT remaining (cratesDue)
  /// - Subtracting from credit amount (amountDue)
  /// - Adding to total collection (amountDue)
  ///
  /// [salesmanName] - The name of the salesman
  /// [date] - The date of the bill
  /// [amountDue] - The amount that was due (now paid)
  /// [cratesDue] - The crates that were due (now returned)
  Future<bool> updateSummaryOnCreditToSale({
    required String salesmanName,
    required DateTime date,
    required int amountDue,
    required int cratesDue,
  }) async {
    try {
      final formattedDate = DateFormat('dd-MMM-yyyy').format(date);

      debugPrint('Updating dashboard summary for credit-to-sale conversion...');
      debugPrint('Date: $formattedDate');
      debugPrint('Amount: $amountDue, Crates: $cratesDue');

      final summaryRef = _firestore
          .collection('Dashboard Summary')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc('summary');

      // Update the summary document
      await summaryRef.set({
        'totalCollection': FieldValue.increment(amountDue),
        'totalCredit': FieldValue.increment(-amountDue),
        'totalMtRemaining': FieldValue.increment(-cratesDue),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Dashboard summary updated successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error updating dashboard summary: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Updates dashboard summary for partial payments (cash or crates received)
  /// This adjusts the summary by:
  /// - Subtracting cash received from credit amount
  /// - Adding cash received to total collection
  /// - Subtracting crates received from MT remaining
  ///
  /// [salesmanName] - The name of the salesman
  /// [date] - The date of the bill
  /// [cashReceived] - The amount received (optional)
  /// [cratesReceived] - The crates returned (optional)
  Future<bool> updateSummaryOnPartialPayment({
    required String salesmanName,
    required DateTime date,
    int? cashReceived,
    int? cratesReceived,
  }) async {
    try {
      // Skip if nothing to update
      if ((cashReceived == null || cashReceived == 0) &&
          (cratesReceived == null || cratesReceived == 0)) {
        return true;
      }

      final formattedDate = DateFormat('dd-MMM-yyyy').format(date);

      debugPrint('Updating dashboard summary for partial payment...');
      debugPrint('Date: $formattedDate');
      debugPrint('Cash: $cashReceived, Crates: $cratesReceived');

      final summaryRef = _firestore
          .collection('Dashboard Summary')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc('summary');

      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (cashReceived != null && cashReceived > 0) {
        updates['totalCollection'] = FieldValue.increment(cashReceived);
        updates['totalCredit'] = FieldValue.increment(-cashReceived);
      }

      if (cratesReceived != null && cratesReceived > 0) {
        updates['totalMtRemaining'] = FieldValue.increment(-cratesReceived);
      }

      // Update the summary document
      await summaryRef.set(updates, SetOptions(merge: true));

      debugPrint('Dashboard summary updated successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error updating dashboard summary: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }
}
