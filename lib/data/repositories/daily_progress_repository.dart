import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:flutter/foundation.dart';

/// Repository for fetching daily sales progress from Firestore.
/// Path: /salesmen/{salesmanDocId}/daily_sales/{date}
class DailyProgressRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches all daily sales records for a salesman (most recent first).
  /// Returns a list of [DailyProgress] documents.
  Future<List<DailyProgress>> fetchDailyProgressList(
    String salesmanDocId,
  ) async {
    try {
      debugPrint('Fetching daily progress for salesman doc: $salesmanDocId');

      final snapshot = await _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('daily_sales')
          .orderBy('date', descending: true)
          .get();

      debugPrint('Found ${snapshot.docs.length} daily progress records');

      final records = snapshot.docs
          .map((doc) => DailyProgress.fromJson(doc.data()))
          .toList();

      return records;
    } catch (e) {
      debugPrint('Error fetching daily progress list: $e');
      rethrow;
    }
  }

  /// Fetches a single daily sales record for a specific date.
  Future<DailyProgress?> fetchDailyProgress(
    String salesmanDocId,
    String date,
  ) async {
    try {
      debugPrint('Fetching daily progress for date: $date');

      final doc = await _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('daily_sales')
          .doc(date)
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('No daily progress found for date: $date');
        return null;
      }

      return DailyProgress.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching daily progress: $e');
      rethrow;
    }
  }
}
