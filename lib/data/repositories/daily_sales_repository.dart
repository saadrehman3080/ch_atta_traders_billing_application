import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:intl/intl.dart';

class DailySalesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
