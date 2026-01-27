import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/salesman.dart';
import 'package:flutter/foundation.dart';

/// Custom exception for when a user doesn't have system access
class NoAccessException implements Exception {
  final String message;
  NoAccessException(this.message);

  @override
  String toString() => message;
}

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
  /// Throws [NoAccessException] if the user does not have access.
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
      debugPrint('salesman hasAccess: ${salesman.hasAccess}');
      debugPrint('salesman isAdmin: ${salesman.isAdmin}');

      // Validate password first
      if (salesman.password != password) {
        debugPrint('Invalid password for salesman ID: $salesmanId');
        return null;
      }

      // Check if salesman has access to the system
      if (!salesman.hasAccess) {
        debugPrint('Salesman $salesmanId does not have access to the system');
        throw NoAccessException('User does not have access to the system');
      }

      debugPrint('Credentials validated for salesman: ${salesman.name}');
      return salesman;
    } catch (e, stackTrace) {
      debugPrint('Error validating credentials: $e');
      debugPrint('StackTrace: $stackTrace');
      // Re-throw NoAccessException so callers can handle it specifically
      if (e is NoAccessException) rethrow;
      return null;
    }
  }
}
