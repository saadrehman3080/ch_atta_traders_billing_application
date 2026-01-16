import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Repository for handling sale data operations with Firestore.
///
/// This class follows the Repository pattern to abstract data access
/// and provide a clean API for the ViewModel layer.
class SaleRepository {
  final FirebaseFirestore _firestore;

  SaleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for daily sales
  static const String _collectionName = 'Daily Sales';

  /// Saves a sale to Firestore and updates the dashboard summary.
  ///
  /// Path: Daily Sales/{salesmanName}/{formattedDate}/{billId}
  /// Summary Path: Dashboard Summary/{salesmanName}/{formattedDate}/summary
  ///
  /// [sale] - The SaleHistory object to save
  /// [salesmanName] - The name of the salesman (from SharedPreferences)
  ///
  /// Returns true if save was successful, false otherwise.
  Future<bool> saveSale(SaleHistory sale, String salesmanName) async {
    try {
      // Format date as 01-Jan-2026
      final formattedDate = DateFormat('dd-MMM-yyyy').format(sale.date);

      debugPrint('Saving sale to Firebase...');
      debugPrint(
        'Path: $_collectionName/$salesmanName/$formattedDate/${sale.billId}',
      );

      // Calculate totals for dashboard
      final totalAmount =
          sale.products.fold<int>(
            0,
            (sum, product) => sum + (product.price * product.quantity),
          ) -
          sale.discount;

      final itemsSold = sale.products.fold<int>(
        0,
        (sum, product) => sum + product.quantity,
      );

      // Use transaction to atomically update both bill and dashboard summary
      await _firestore.runTransaction((transaction) async {
        // Reference to the sale document (in Daily Sales)
        final saleRef = _firestore
            .collection(_collectionName)
            .doc(salesmanName)
            .collection(formattedDate)
            .doc(sale.billId);

        // Reference to the dashboard summary document (separate collection)
        final dashboardSummaryRef = _firestore
            .collection('Dashboard Summary')
            .doc(salesmanName)
            .collection(formattedDate)
            .doc('summary');

        // Save the sale document
        transaction.set(saleRef, sale.toJson());

        // Update dashboard summary - CASH BILL: totalCollection, itemsSold, discount, customersServed
        transaction.set(dashboardSummaryRef, {
          'totalCollection': FieldValue.increment(totalAmount),
          'totalItemsSold': FieldValue.increment(itemsSold),
          'totalDiscount': FieldValue.increment(sale.discount),
          'customersServed': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      debugPrint(
        'Sale and dashboard summary saved successfully: ${sale.billId}',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error saving sale: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Saves a sale converted from credit WITHOUT incrementing customersServed.
  /// Used when moving a credit record to sale history after full payment.
  /// The customer was already counted when the credit was created.
  ///
  /// [sale] - The SaleHistory object to save
  /// [salesmanName] - The name of the salesman
  ///
  /// Returns true if save was successful, false otherwise.
  Future<bool> saveSaleFromCreditConversion(
    SaleHistory sale,
    String salesmanName,
  ) async {
    try {
      // Format date as 01-Jan-2026
      final formattedDate = DateFormat('dd-MMM-yyyy').format(sale.date);

      debugPrint('Saving sale from credit conversion to Firebase...');
      debugPrint(
        'Path: $_collectionName/$salesmanName/$formattedDate/${sale.billId}',
      );

      // Reference to the sale document (in Daily Sales)
      final saleRef = _firestore
          .collection(_collectionName)
          .doc(salesmanName)
          .collection(formattedDate)
          .doc(sale.billId);

      // Save only the sale document, no dashboard update
      // Dashboard updates are handled separately by updateSummaryOnCreditToSale
      await saleRef.set(sale.toJson());

      debugPrint(
        'Sale saved from credit conversion successfully: ${sale.billId}',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error saving sale from credit conversion: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Fetches sales for a specific salesman and date.
  ///
  /// [salesmanName] - The name of the salesman
  /// [date] - The date to fetch sales for
  ///
  /// Returns a list of [SaleHistory] objects.
  Future<List<SaleHistory>> fetchSalesForDate(
    String salesmanName,
    DateTime date,
  ) async {
    try {
      final formattedDate = DateFormat('dd-MMM-yyyy').format(date);

      debugPrint('Fetching sales from Firebase...');
      debugPrint('Path: $_collectionName/$salesmanName/$formattedDate');

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .doc(salesmanName)
          .collection(formattedDate)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No sales found for $formattedDate');
        return [];
      }

      final sales = querySnapshot.docs.map((doc) {
        return SaleHistory.fromJson(doc.data());
      }).toList();

      debugPrint('Fetched ${sales.length} sales from Firebase');
      return sales;
    } catch (e, stackTrace) {
      debugPrint('Error fetching sales: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }
}
