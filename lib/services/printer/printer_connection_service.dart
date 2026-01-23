import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Centralized service for managing printer connection status
class PrinterConnectionService extends ChangeNotifier {
  PrinterConnectionService._internal();

  static final PrinterConnectionService _instance =
      PrinterConnectionService._internal();

  /// Get the singleton instance
  static PrinterConnectionService get instance => _instance;

  bool _isConnected = false;

  /// Whether the printer is currently connected
  bool get isConnected => _isConnected;

  /// Check the current printer connection status
  Future<bool> checkConnection() async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (_isConnected != isConnected) {
        _isConnected = isConnected;
        notifyListeners();
      }
      return isConnected;
    } catch (e) {
      debugPrint('Error checking printer connection: $e');
      if (_isConnected != false) {
        _isConnected = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Update connection status (called after successful connection/disconnection)
  void updateConnectionStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    }
  }
}
