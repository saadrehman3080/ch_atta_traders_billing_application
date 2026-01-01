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
}
