import 'package:ch_atta_traders_billing_application/data/models/offline_dashboard_payload.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores dashboard delta payloads for each bill until successful online push.
class OfflineDashboardQueueService {
  static const String _boxName = 'pending_dashboard_data';

  Box<Map> get _box => Hive.box<Map>(_boxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Map>(_boxName);
    }
  }

  Future<void> savePayload(OfflineDashboardPayload payload) async {
    await _box.put(payload.billId, payload.toJson());
    debugPrint(
      '[OfflineDashboardQueueService] Saved payload: ${payload.billId}',
    );
  }

  OfflineDashboardPayload? getPayload(String billId) {
    final raw = _box.get(billId);
    if (raw == null) return null;
    return OfflineDashboardPayload.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> deletePayload(String billId) async {
    await _box.delete(billId);
    debugPrint('[OfflineDashboardQueueService] Deleted payload: $billId');
  }
}
