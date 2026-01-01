import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/salesman.dart';
import 'package:flutter/foundation.dart';

/// Repository for handling salesman data operations with Firestore.
///
/// This class follows the Repository pattern to abstract data access
/// and provide a clean API for the ViewModel layer.
class SalesmanRepository {
  final FirebaseFirestore _firestore;

  SalesmanRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for salesmen documents
  static const String _collectionName = 'salesmen';

  /// Validates salesman credentials against the database.
  ///
  /// [salesmanId] - The salesman ID entered by the user
  /// [password] - The password entered by the user
  ///
  /// Returns the [Salesman] object if credentials are valid, null otherwise.
  Future<Salesman?> validateCredentials(int salesmanId, int password) async {
    try {
      // Query for salesman with matching salesmanId
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('salesmanId', isEqualTo: salesmanId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No salesman found with ID: $salesmanId');
        return null;
      }

      final doc = querySnapshot.docs.first;
      final salesman = Salesman.fromFirestore(doc.id, doc.data());
      debugPrint('Complete salesman Object: ${salesman.toString()}');
      debugPrint('salesman password: ${salesman.password}');
      // Validate password
      if (salesman.password == password) {
        debugPrint('Credentials validated for salesman: ${salesman.name}');
        return salesman;
      } else {
        debugPrint('Invalid password for salesman ID: $salesmanId');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error validating credentials: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }
}
