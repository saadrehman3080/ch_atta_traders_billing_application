import 'dart:async';

import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/pending_bill.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/credit_repository.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/sale_repository.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_bill_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Manages syncing [PendingBill] objects from Hive to Firestore.
///
/// Architecture:
///   Save locally → Print → Background sync
///                          ↓
///                    Success → remove from Hive
///                    Failure → retry with exponential backoff
class OfflineBillSyncManager {
  OfflineBillSyncManager._();

  static final OfflineBillSyncManager _instance = OfflineBillSyncManager._();

  static OfflineBillSyncManager get instance => _instance;

  // ─── Dependencies ────────────────────────────────────────────────────────

  final OfflineBillService _offlineBillService = OfflineBillService();
  final SaleRepository _saleRepository = SaleRepository();
  final CreditRepository _creditRepository = CreditRepository();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  // ─── Connectivity Listener ────────────────────────────────────────────────

  /// Call once from [main] to start listening for connectivity changes.
  /// Adds a 5-second delay before syncing to avoid sync storms during
  /// brief network flaps.
  void startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) return;

      // Delay to avoid sync storms on flaky connections.
      await Future<void>.delayed(const Duration(seconds: 5));

      await syncPendingBills();
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Fires a background sync for a single [bill].
  /// Silently skips if the device is offline — the connectivity listener
  /// will pick up all pending bills once the connection is restored.
  static Future<void> syncBill(PendingBill bill) async {
    unawaited(instance._attemptSyncIfOnline(bill));
  }

  Future<void> _attemptSyncIfOnline(PendingBill bill) async {
    if (!(await _isOnline())) {
      debugPrint(
        '[OfflineBillSyncManager] Offline — ${bill.billId} queued for later.',
      );
      return; // bill stays as pending in Hive; connectivity listener retries
    }
    await _syncSingleBill(bill);
  }

  /// Syncs ALL pending bills, respecting exponential backoff.
  /// Returns a map with 'synced' and 'failed' counts.
  /// Returns immediately with zeros if the device is offline.
  static Future<Map<String, int>> syncPendingBills() async {
    // Don't waste time on Firebase calls if we know we're offline.
    if (!(await _isOnline())) {
      debugPrint('[OfflineBillSyncManager] Offline — skipping batch sync.');
      return {'synced': 0, 'failed': 0};
    }

    if (instance._isSyncing) return {'synced': 0, 'failed': 0};
    instance._isSyncing = true;

    int synced = 0;
    int failed = 0;

    try {
      final pendingBills = instance._offlineBillService.getPendingBills();

      debugPrint(
        '[OfflineBillSyncManager] Syncing ${pendingBills.length} pending bill(s).',
      );

      for (final bill in pendingBills) {
        if (!instance._shouldRetry(bill)) continue;

        final success = await instance._syncSingleBill(bill);
        if (success) {
          synced++;
        } else {
          failed++;
        }
      }
    } finally {
      instance._isSyncing = false;
    }

    debugPrint(
      '[OfflineBillSyncManager] Sync complete. Synced: $synced, Failed: $failed',
    );
    return {'synced': synced, 'failed': failed};
  }

  // ─── Connectivity Helper ──────────────────────────────────────────────────

  /// Returns true if the device reports any active network interface.
  /// This is a fast local check — no actual HTTP request is made.
  /// The 10-second Firebase timeout handles the edge case where the network
  /// interface is up but internet is not reachable (e.g. captive portal).
  static Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ─── Retry Backoff ────────────────────────────────────────────────────────

  bool _shouldRetry(PendingBill bill) {
    if (bill.lastSyncAttempt == null) return true;

    final elapsed = DateTime.now().difference(bill.lastSyncAttempt!);

    switch (bill.syncAttempts) {
      case 0:
        return true;
      case 1:
        return elapsed.inMinutes >= 1;
      case 2:
        return elapsed.inMinutes >= 5;
      case 3:
        return elapsed.inMinutes >= 15;
      case 4:
        return elapsed.inHours >= 1;
      default:
        return elapsed.inHours >= 6;
    }
  }

  // ─── Sync a Single Bill ───────────────────────────────────────────────────

  Future<bool> _syncSingleBill(PendingBill bill) async {
    try {
      await _markSyncing(bill);

      await _saveToFirebaseWithTimeout(
        bill,
        timeout: const Duration(seconds: 10),
      );

      await _offlineBillService.deletePendingBill(bill.billId);
      debugPrint('[OfflineBillSyncManager] Synced bill: ${bill.billId}');
      return true;
    } catch (e) {
      await _markFailed(bill);
      debugPrint('[OfflineBillSyncManager] Sync failed for ${bill.billId}: $e');
      return false;
    }
  }

  // ─── Status Helpers ───────────────────────────────────────────────────────

  Future<void> _markSyncing(PendingBill bill) async {
    final updated = bill.copyWith(status: PendingBillStatus.syncing);
    await _offlineBillService.updatePendingBill(updated);
  }

  Future<void> _markFailed(PendingBill bill) async {
    final updated = bill.copyWith(
      status: PendingBillStatus.failed,
      syncAttempts: bill.syncAttempts + 1,
      lastSyncAttempt: DateTime.now(),
    );
    await _offlineBillService.updatePendingBill(updated);
  }

  // ─── Firebase Write ───────────────────────────────────────────────────────

  Future<void> _saveToFirebaseWithTimeout(
    PendingBill bill, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _saveToFirebase(bill).timeout(timeout);
  }

  /// Reconstructs the original [SaleHistory] or [CreditHistory] from [bill]
  /// and delegates the write to the appropriate repository.
  Future<void> _saveToFirebase(PendingBill bill) async {
    final products = bill.productsJson.map((j) => Product.fromJson(j)).toList();

    if (bill.billType == 'sale') {
      final saleHistory = SaleHistory(
        billId: bill.billId,
        customerName: bill.customerName,
        date: bill.date,
        products: products,
        discount: bill.discount,
        billType: BillType.fromJson(bill.paymentType),
      );
      final ok = await _saleRepository.saveSale(
        saleHistory,
        bill.salesmanIdentifier,
      );
      if (!ok) throw Exception('SaleRepository.saveSale returned false');
    } else {
      final partialPayments = bill.partialPaymentsJson
          .map((j) => PartialPayment.fromJson(j))
          .toList();

      final creditHistory = CreditHistory(
        billId: bill.billId,
        customerName: bill.customerName,
        date: bill.date,
        products: products,
        discount: bill.discount,
        isPaid: bill.isPaid,
        amountDue: bill.amountDue,
        cratesDue: bill.cratesDue,
        billType: BillType.credit,
        partialPayments: partialPayments,
      );
      await _creditRepository.saveCredit(
        creditHistory,
        bill.salesmanIdentifier,
      );
    }
  }
}
