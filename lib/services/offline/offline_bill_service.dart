import 'package:ch_atta_traders_billing_application/data/models/pending_bill.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Low-level service for persisting [PendingBill] objects in a local Hive box.
///
/// All public methods are intentionally thin wrappers around Hive so that the
/// rest of the app never imports Hive directly.
class OfflineBillService {
  static const String _boxName = 'pending_bills';

  Box<PendingBill> get _box => Hive.box<PendingBill>(_boxName);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Opens the Hive box. Call once during app start (before any other method).
  /// Also resets any bills stuck in [PendingBillStatus.syncing] (left over
  /// from a previous app crash mid-sync) so they are retried.
  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<PendingBill>(_boxName);
    }
    await _resetStuckSyncingBills();
  }

  /// Resets bills whose status was left as [PendingBillStatus.syncing]
  /// (i.e. the app crashed between marking syncing and completing the write)
  /// back to [PendingBillStatus.failed] so they are retried on next sync.
  static Future<void> _resetStuckSyncingBills() async {
    final box = Hive.box<PendingBill>(_boxName);
    final stuck = box.values
        .where((b) => b.status == PendingBillStatus.syncing)
        .toList();
    for (final bill in stuck) {
      await box.put(
        bill.billId,
        bill.copyWith(status: PendingBillStatus.failed),
      );
    }
    if (stuck.isNotEmpty) {
      debugPrint(
        '[OfflineBillService] Reset ${stuck.length} stuck syncing bill(s) to failed.',
      );
    }
  }

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Persists [bill] locally. Uses [billId] as the key so re-saves are safe.
  Future<void> savePendingBill(PendingBill bill) async {
    await _box.put(bill.billId, bill);
    debugPrint('[OfflineBillService] Saved pending bill: ${bill.billId}');
  }

  /// Replaces the stored bill with [updated] (same key).
  Future<void> updatePendingBill(PendingBill updated) async {
    await _box.put(updated.billId, updated);
  }

  // ─── Read ──────────────────────────────────────────────────────────────────

  /// Returns all bills that still need to be synced
  /// (status is [PendingBillStatus.pending] or [PendingBillStatus.failed]).
  List<PendingBill> getPendingBills() {
    return _box.values
        .where(
          (b) =>
              b.status == PendingBillStatus.pending ||
              b.status == PendingBillStatus.failed,
        )
        .toList();
  }

  /// Returns every stored bill regardless of status.
  List<PendingBill> getAllPendingBills() => _box.values.toList();

  /// Returns the count of bills still pending sync.
  int get pendingCount => getPendingBills().length;

  /// A [ValueListenable] for the Hive box so UI widgets can reactively
  /// rebuild whenever any bill is added, updated, or deleted.
  static ValueListenable<Box<PendingBill>> get boxListenable =>
      Hive.box<PendingBill>(_boxName).listenable();

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// Removes a successfully synced bill.
  Future<void> deletePendingBill(String billId) async {
    await _box.delete(billId);
    debugPrint('[OfflineBillService] Deleted synced bill: $billId');
  }
}
