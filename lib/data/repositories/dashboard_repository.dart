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
}
