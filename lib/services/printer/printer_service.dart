import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_state.dart';

/// Service class to manage Bluetooth thermal printer operations
///
/// This service handles:
/// - Printer scanning and discovery
/// - Connection/disconnection management
/// - Auto-connection to saved printers
/// - Connection monitoring and battery level tracking
/// - State management for UI updates
class PrinterService extends ChangeNotifier {
  PrinterState _state = const PrinterState();
  Timer? _connectionMonitorTimer;
  Timer? _initialConnectionCheckTimer;

  PrinterState get state => _state;

  /// Singleton instance
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  /// Initialize the printer service
  Future<void> initialize() async {
    debugPrint('[PrinterService] Initializing...');
    await scanForPrinters();
    _startConnectionMonitoring();
  }

  /// Scan for available Bluetooth printers
  Future<void> scanForPrinters() async {
    debugPrint('[PrinterService] Scanning for printers...');
    _updateState(_state.copyWith(isScanning: true, clearError: true));

    try {
      // Check if Bluetooth is available
      final isAvailable = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isAvailable) {
        _updateState(
          _state.copyWith(
            isScanning: false,
            errorMessage: 'Bluetooth is not enabled',
          ),
        );
        return;
      }

      // Scan for paired devices
      final printers = await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('[PrinterService] Found ${printers.length} printer(s)');

      _updateState(
        _state.copyWith(availablePrinters: printers, isScanning: false),
      );

      // After scanning, check for existing connection
      await checkExistingConnection();
    } catch (e) {
      debugPrint('[PrinterService] Error scanning: $e');
      _updateState(
        _state.copyWith(
          isScanning: false,
          errorMessage: 'Failed to scan for printers',
        ),
      );
    }
  }

  /// Check if a printer is already connected (e.g., from auto-connect)
  Future<void> checkExistingConnection() async {
    try {
      debugPrint('[PrinterService] Checking existing connection...');
      final isConnected = await PrintBluetoothThermal.connectionStatus;

      if (isConnected) {
        final savedAddress = await AppPreferences.instance.printerAddress;
        debugPrint('[PrinterService] Found active connection: $savedAddress');

        if (savedAddress != null && savedAddress.isNotEmpty) {
          _updateState(
            _state.copyWith(
              connectedPrinterAddress: savedAddress,
              clearConnectingAddress: true,
            ),
          );
          debugPrint('[PrinterService] Updated state with existing connection');
        }
      } else {
        debugPrint('[PrinterService] No active connection found');
      }
    } catch (e) {
      debugPrint('[PrinterService] Error checking existing connection: $e');
    }
  }

  /// Connect to a specific printer
  Future<bool> connectToPrinter(BluetoothInfo printer) async {
    debugPrint('[PrinterService] Connecting to ${printer.name}...');
    _updateState(
      _state.copyWith(
        connectingPrinterAddress: printer.macAdress,
        clearError: true,
      ),
    );

    try {
      final result =
          await PrintBluetoothThermal.connect(
            macPrinterAddress: printer.macAdress,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );

      if (result) {
        debugPrint('[PrinterService] Connected successfully');

        // Save to SharedPreferences
        await AppPreferences.instance.setPrinterAddress(printer.macAdress);

        _updateState(
          _state.copyWith(
            connectedPrinterAddress: printer.macAdress,
            clearConnectingAddress: true,
          ),
        );

        return true;
      } else {
        throw Exception('Connection failed');
      }
    } on TimeoutException {
      debugPrint('[PrinterService] Connection timeout');
      _updateState(
        _state.copyWith(
          errorMessage: 'Connection timeout',
          clearConnectingAddress: true,
        ),
      );
      return false;
    } catch (e) {
      debugPrint('[PrinterService] Connection error: $e');
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to connect to printer',
          clearConnectingAddress: true,
        ),
      );
      return false;
    }
  }

  /// Disconnect from the current printer
  Future<bool> disconnect() async {
    debugPrint('[PrinterService] Disconnecting...');
    try {
      await PrintBluetoothThermal.disconnect;

      _updateState(_state.copyWith(clearConnectedAddress: true));

      debugPrint('[PrinterService] Disconnected successfully');
      return true;
    } catch (e) {
      debugPrint('[PrinterService] Disconnect error: $e');
      return false;
    }
  }

  /// Auto-connect to saved printer
  Future<bool> autoConnect() async {
    try {
      debugPrint('[PrinterService] Attempting auto-connect...');

      // Check if Bluetooth is enabled
      final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) {
        debugPrint('[PrinterService] Bluetooth not enabled');
        return false;
      }

      // Get saved printer address
      final savedAddress = await AppPreferences.instance.printerAddress;
      if (savedAddress == null || savedAddress.isEmpty) {
        debugPrint('[PrinterService] No saved printer address');
        return false;
      }

      // Check if already connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        debugPrint('[PrinterService] Already connected');
        _updateState(_state.copyWith(connectedPrinterAddress: savedAddress));
        return true;
      }

      // Attempt to connect
      debugPrint('[PrinterService] Connecting to saved printer: $savedAddress');
      final result =
          await PrintBluetoothThermal.connect(
            macPrinterAddress: savedAddress,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[PrinterService] Auto-connect timeout');
              return false;
            },
          );

      if (result) {
        debugPrint('[PrinterService] Auto-connect successful');
        _updateState(_state.copyWith(connectedPrinterAddress: savedAddress));
        return true;
      } else {
        debugPrint('[PrinterService] Auto-connect failed');
        return false;
      }
    } catch (e) {
      debugPrint('[PrinterService] Auto-connect error: $e');
      return false;
    }
  }

  /// Start monitoring connection status
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _verifyConnection(),
    );
    debugPrint('[PrinterService] Connection monitoring started');
  }

  /// Verify current printer connection
  Future<void> _verifyConnection() async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;

      if (!isConnected && _state.isConnected) {
        debugPrint('[PrinterService] Connection lost');
        _updateState(_state.copyWith(clearConnectedAddress: true));
      } else if (isConnected) {
        // Ensure we have the correct address
        if (!_state.isConnected) {
          final savedAddress = await AppPreferences.instance.printerAddress;
          if (savedAddress != null && savedAddress.isNotEmpty) {
            debugPrint('[PrinterService] Restoring connection address');
            _updateState(
              _state.copyWith(connectedPrinterAddress: savedAddress),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PrinterService] Error verifying connection: $e');
    }
  }

  /// Update state and notify listeners
  void _updateState(PrinterState newState) {
    _state = newState;
    notifyListeners();
    debugPrint('[PrinterService] State updated: $_state');
  }

  /// Check if a specific printer is connected
  bool isPrinterConnected(String macAddress) {
    return _state.connectedPrinterAddress == macAddress;
  }

  /// Check if a specific printer is being connected
  bool isPrinterConnecting(String macAddress) {
    return _state.connectingPrinterAddress == macAddress;
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectionMonitorTimer?.cancel();
    _initialConnectionCheckTimer?.cancel();
    debugPrint('[PrinterService] Disposed');
    super.dispose();
  }
}
