import 'dart:async';

import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_bill_service.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_bill_sync_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// A small widget that shows the count of pending (un-synced) bills and lets
/// the user manually trigger a sync. Place it anywhere in the UI where sync
/// status should be visible (e.g. home screen app bar, drawer header).
///
/// Usage:
/// ```dart
/// PendingBillsSyncWidget(
///   onSyncComplete: (result) {
///     // result is {'synced': n, 'failed': m}
///   },
/// )
/// ```
class PendingBillsSyncWidget extends StatefulWidget {
  final void Function(Map<String, int> result)? onSyncComplete;
  final Color? accentColor;

  const PendingBillsSyncWidget({
    super.key,
    this.onSyncComplete,
    this.accentColor,
  });

  @override
  State<PendingBillsSyncWidget> createState() => _PendingBillsSyncWidgetState();
}

class _PendingBillsSyncWidgetState extends State<PendingBillsSyncWidget> {
  final OfflineBillService _offlineBillService = OfflineBillService();
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  int _pendingBillCount = 0;
  bool _isSyncing = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkPendingBills();
    _initConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    });
  }

  // ─── State Helpers ────────────────────────────────────────────────────────

  Future<void> _checkPendingBills() async {
    if (!mounted) return;
    setState(() {
      _pendingBillCount = _offlineBillService.pendingCount;
    });
  }

  // ─── Sync Handler ─────────────────────────────────────────────────────────

  Future<void> _handleSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final result = await OfflineBillSyncManager.syncPendingBills();

      // Re-check actual count from Hive after sync.
      await _checkPendingBills();

      widget.onSyncComplete?.call(result);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_pendingBillCount == 0 && !_isSyncing) return const SizedBox.shrink();
    if (!_isOnline && !_isSyncing) return const SizedBox.shrink();

    final color = widget.accentColor ?? AppColors.pepsiBlue;

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _isSyncing ? null : _handleSync,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isSyncing
                ? AppColors.gray100
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isSyncing
                  ? AppColors.gray300
                  : color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSyncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(Icons.cloud_upload_outlined, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                _isSyncing ? 'Syncing...' : 'Sync Now',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
