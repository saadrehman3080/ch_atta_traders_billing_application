import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:ch_atta_traders_billing_application/data/models/progress_snapshot.dart';
import 'package:flutter/foundation.dart';

/// Repository for fetching daily sales progress from Firestore.
///
/// Supports two modes:
/// 1. **Full fetch** – [fetchDailyProgressList] loads every record (legacy).
/// 2. **Optimised fetch** – [fetchProgressSnapshot] + [fetchProgressAfterDate]
///    loads only a compact snapshot document plus the most recent records,
///    cutting Firestore reads dramatically as the dataset grows.
///
/// Path: /salesmen/{salesmanDocId}/daily_sales/{date}
class DailyProgressRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Legacy – Full Fetch
  // ---------------------------------------------------------------------------

  /// Fetches **all** daily sales records for a salesman (most recent first).
  ///
  /// Only used on the very first load when no snapshot exists. After the
  /// snapshot is written this method is no longer called.
  Future<List<DailyProgress>> fetchDailyProgressList(
    String salesmanDocId,
  ) async {
    try {
      debugPrint(
        'Fetching ALL daily progress for salesman doc: $salesmanDocId',
      );

      final snapshot = await _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('daily_sales')
          .orderBy('date', descending: true)
          .get();

      debugPrint('Found ${snapshot.docs.length} daily progress records');

      return snapshot.docs
          .map((doc) => DailyProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching daily progress list: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Optimised – Snapshot + Incremental Fetch
  // ---------------------------------------------------------------------------

  /// Fetches the running‑total snapshot for a salesman.
  ///
  /// Returns `null` when no snapshot has been written yet (first‑time use).
  /// Firestore path: `/salesmen/{docId}/progress_snapshots/latest`
  Future<ProgressSnapshot?> fetchProgressSnapshot(String salesmanDocId) async {
    try {
      final doc = await _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('progress_snapshots')
          .doc('latest')
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return ProgressSnapshot.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching progress snapshot: $e');
      return null;
    }
  }

  /// Persists (creates or overwrites) the running‑total snapshot.
  Future<void> saveProgressSnapshot(
    String salesmanDocId,
    ProgressSnapshot snapshot,
  ) async {
    try {
      await _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('progress_snapshots')
          .doc('latest')
          .set(snapshot.toJson());
      debugPrint('Saved progress snapshot: $snapshot');
    } catch (e) {
      debugPrint('Error saving progress snapshot: $e');
      // Non‑fatal – the app still works; snapshot will be retried next load.
    }
  }

  /// Fetches only daily progress records whose `date` is strictly **after**
  /// [afterDate] (YYYY‑MM‑DD), ordered most‑recent‑first.
  ///
  /// When [afterDate] is empty every record is returned (same as full fetch
  /// but through the optimised path).
  Future<List<DailyProgress>> fetchProgressAfterDate(
    String salesmanDocId,
    String afterDate,
  ) async {
    try {
      debugPrint(
        'Fetching daily progress after $afterDate for doc: $salesmanDocId',
      );

      Query<Map<String, dynamic>> query = _firestore
          .collection('salesmen')
          .doc(salesmanDocId)
          .collection('daily_sales');

      if (afterDate.isNotEmpty) {
        query = query.where('date', isGreaterThan: afterDate);
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();

      debugPrint('Found ${snapshot.docs.length} records after $afterDate');

      return snapshot.docs
          .map((doc) => DailyProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching progress after date: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Single Record
  // ---------------------------------------------------------------------------

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
