import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/core/utils/date_formatters.dart';
import 'package:ch_atta_traders_billing_application/data/models/dashboard_data.dart';
import 'package:ch_atta_traders_billing_application/services/dashboard_summary_service.dart';
import 'package:flutter/foundation.dart';

/// Repository for fetching dashboard summary data from Firestore.
///
/// This class fetches pre-aggregated summary document from the
/// centralized Dashboard Summary collection for O(1) dashboard reads.
/// For updates, it delegates to DashboardSummaryService.
class DashboardRepository {
  final FirebaseFirestore _firestore;
  final DashboardSummaryService _dashboardService;

  DashboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _dashboardService = DashboardSummaryService();

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
      final formattedDate = DateFormatters.formatForFirebase(targetDate);

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

  // ========== DELEGATED METHODS TO DASHBOARD SUMMARY SERVICE ==========

  /// Updates dashboard summary when converting a credit bill to sale
  /// Delegates to DashboardSummaryService
  Future<bool> updateSummaryOnCreditToSale({
    required String salesmanName,
    required DateTime date,
    required int amountDue,
    required int cratesDue,
    required bool isPaidBill,
  }) async {
    return _dashboardService.onCreditConvertedToSale(
      salesmanName: salesmanName,
      date: date,
      amountDue: amountDue,
      cratesDue: cratesDue,
      isPaidBill: isPaidBill,
    );
  }

  /// Updates dashboard summary for partial payments (cash or crates received)
  /// Delegates to DashboardSummaryService
  Future<bool> updateSummaryOnPartialPayment({
    required String salesmanName,
    required DateTime date,
    int? cashReceived,
    int? cratesReceived,
    required bool isPaidBill,
  }) async {
    return _dashboardService.onPartialPaymentReceived(
      salesmanName: salesmanName,
      date: date,
      cashReceived: cashReceived,
      cratesReceived: cratesReceived,
      isPaidBill: isPaidBill,
    );
  }

  /// Updates dashboard summary when a credit bill is deleted permanently
  /// Delegates to DashboardSummaryService
  Future<bool> updateSummaryOnCreditDelete({
    required String salesmanName,
    required DateTime date,
    required int amountDue,
    required int cratesDue,
    required int itemsSold,
    required int discount,
    required bool isPaidBill,
  }) async {
    return _dashboardService.onCreditDeleted(
      salesmanName: salesmanName,
      date: date,
      amountDue: amountDue,
      cratesDue: cratesDue,
      itemsSold: itemsSold,
      discount: discount,
      isPaidBill: isPaidBill,
    );
  }
}
