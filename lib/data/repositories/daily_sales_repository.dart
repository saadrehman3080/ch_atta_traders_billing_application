import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/services/dashboard_summary_service.dart';
import 'package:intl/intl.dart';

class DailySalesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DashboardSummaryService _dashboardService = DashboardSummaryService();

  /// Fetches all sales for a specific salesman and date
  /// Path: Daily Sales/{salesmanName}/{dd-MMM-yyyy}
  Future<List<SaleHistory>> fetchDailySales(
    String salesmanName,
    DateTime date,
  ) async {
    try {
      // Format date as dd-MMM-yyyy (e.g., 01-Jan-2026)
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final formattedDate = dateFormat.format(date);

      print('Fetching daily sales from Firestore...');
      print('Salesman: $salesmanName');
      print('Date: $formattedDate');

      // Get all documents in the date subcollection
      final snapshot = await _firestore
          .collection('Daily Sales')
          .doc(salesmanName)
          .collection(formattedDate)
          .get();

      print('Found ${snapshot.docs.length} sales');

      // Convert documents to SaleHistory objects
      final sales = snapshot.docs
          .map((doc) => SaleHistory.fromJson(doc.data()))
          .toList();

      // Sort by date descending (most recent first)
      sales.sort((a, b) => b.date.compareTo(a.date));

      return sales;
    } catch (e) {
      print('Error fetching daily sales: $e');
      rethrow;
    }
  }

  /// Deletes a sale from sales history, updates dashboard, and moves to deleted history
  /// Path: Daily Sales/{salesmanName}/{dd-MMM-yyyy}/{billId}
  /// Deleted Path: Deleted History/{salesmanName}/{d-MMM-yyyy}/{billId}
  Future<void> deleteSale({
    required SaleHistory sale,
    required String salesmanName,
  }) async {
    try {
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final deleteDateFormat = DateFormat('d-MMM-yyyy');
      final formattedDate = dateFormat.format(sale.date);
      final deleteFormattedDate = deleteDateFormat.format(sale.date);

      // Save to deleted history
      final deleteHistoryPath =
          'Deleted History/$salesmanName/$deleteFormattedDate/${sale.billId}';

      final saleData = {
        'billId': sale.billId,
        'customerName': sale.customerName,
        'date': Timestamp.fromDate(sale.date),
        'products': sale.products.map((p) => p.toJson()).toList(),
        'discount': sale.discount,
        'deletedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.doc(deleteHistoryPath).set(saleData);

      // Calculate totals for dashboard update
      final grandTotal =
          sale.products.fold<int>(0, (sum, p) => sum + (p.price * p.quantity)) -
          sale.discount;
      final itemsSold = sale.products.fold<int>(
        0,
        (sum, p) => sum + p.quantity,
      );

      // Update dashboard summary using centralized service
      await _dashboardService.onSaleDeleted(
        salesmanName: salesmanName,
        date: sale.date,
        totalAmount: grandTotal,
        itemsSold: itemsSold,
        discount: sale.discount,
      );

      // Delete from sales history
      await _firestore
          .collection('Daily Sales')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc(sale.billId)
          .delete();

      print('Sale deleted successfully');
    } catch (e) {
      print('Error deleting sale: $e');
      rethrow;
    }
  }

  /// Converts a sale to credit, updates dashboard, and moves record
  /// From: Daily Sales/{salesmanName}/{dd-MMM-yyyy}/{billId}
  /// To: Credit History/{salesmanName}/{dd-MMM-yyyy}/{billId}
  Future<void> convertSaleToCredit({
    required SaleHistory sale,
    required String salesmanName,
  }) async {
    try {
      final dateFormat = DateFormat('dd-MMM-yyyy');
      final formattedDate = dateFormat.format(sale.date);

      // Calculate grand total for amountDue
      final grandTotal =
          sale.products.fold<int>(0, (sum, p) => sum + (p.price * p.quantity)) -
          sale.discount;

      final itemsSold = sale.products.fold<int>(
        0,
        (sum, p) => sum + p.quantity,
      );

      // Create credit history record with:
      // - amountDue = grandTotal (full payment due)
      // - cratesDue = 0 (MT fully received)
      // - isPaid = false (since it's credit)
      final creditData = {
        'billId': sale.billId,
        'customerName': sale.customerName,
        'date': Timestamp.fromDate(sale.date),
        'products': sale.products.map((p) => p.toJson()).toList(),
        'discount': sale.discount,
        'amountDue': grandTotal,
        'cratesDue': 0, // MT fully received
        'isPaid': false,
      };

      // Save to credit history
      await _firestore
          .collection('Credit History')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc(sale.billId)
          .set(creditData);

      // Update dashboard summary using centralized service
      await _dashboardService.onSaleConvertedToCredit(
        salesmanName: salesmanName,
        date: sale.date,
        totalAmount: grandTotal,
        itemsSold: itemsSold,
      );

      // Delete from sales history
      await _firestore
          .collection('Daily Sales')
          .doc(salesmanName)
          .collection(formattedDate)
          .doc(sale.billId)
          .delete();

      print('Sale converted to credit successfully');
    } catch (e) {
      print('Error converting sale to credit: $e');
      rethrow;
    }
  }
}
