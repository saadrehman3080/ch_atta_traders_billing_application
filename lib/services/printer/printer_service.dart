import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_state.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_connection_service.dart';

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

  /// Request all necessary Bluetooth permissions based on Android version
  Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      debugPrint('[PrinterService] Requesting Bluetooth permissions...');

      // Get Android SDK version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      debugPrint('[PrinterService] Android SDK: $sdkInt');

      Map<Permission, PermissionStatus> statuses;

      if (sdkInt >= 31) {
        // Android 12+ (API 31+) - Need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        debugPrint('[PrinterService] Requesting Android 12+ permissions');
        statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
      } else if (sdkInt >= 29) {
        // Android 10-11 (API 29-30) - Need Location permission
        debugPrint('[PrinterService] Requesting Android 10-11 permissions');

        // First request location permission
        statuses = await [Permission.location].request();

        // Check if location services are enabled
        if (statuses[Permission.location]?.isGranted == true) {
          final serviceStatus = await Permission.location.serviceStatus;
          if (serviceStatus != ServiceStatus.enabled) {
            _updateState(
              _state.copyWith(
                errorMessage:
                    'Location services are disabled. Please enable Location in device settings to scan for Bluetooth devices.',
              ),
            );
            return false;
          }
        }
      } else {
        // Android 9 and below - Legacy Bluetooth permissions (usually auto-granted)
        debugPrint('[PrinterService] Android 9 or below - checking Bluetooth');
        return true; // Legacy permissions are granted at install time
      }

      // Check if all permissions are granted
      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        // Check for permanently denied permissions
        bool anyPermanentlyDenied = statuses.values.any(
          (status) => status.isPermanentlyDenied,
        );

        if (anyPermanentlyDenied) {
          _updateState(
            _state.copyWith(
              errorMessage:
                  'Bluetooth permissions denied. Please enable them in Settings → Apps → Permissions.',
            ),
          );
        } else {
          _updateState(
            _state.copyWith(
              errorMessage:
                  'Bluetooth permissions are required to scan for printers. Please grant the permissions.',
            ),
          );
        }

        debugPrint('[PrinterService] Permissions denied: $statuses');
        return false;
      }

      debugPrint('[PrinterService] All permissions granted');
      return true;
    } catch (e, st) {
      debugPrint('[PrinterService] Error requesting permissions: $e\n$st');
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to request permissions: ${e.toString()}',
        ),
      );
      return false;
    }
  }

  /// Scan for available Bluetooth printers
  Future<void> scanForPrinters() async {
    debugPrint('[PrinterService] Scanning for printers...');
    _updateState(_state.copyWith(isScanning: true, clearError: true));

    try {
      // --- 1) REQUEST PERMISSIONS FIRST ---
      final hasPermissions = await requestBluetoothPermissions();
      if (!hasPermissions) {
        _updateState(_state.copyWith(isScanning: false));
        return;
      }

      // --- 2) BLUETOOTH ENABLED CHECK ---
      final isAvailable = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isAvailable) {
        _updateState(
          _state.copyWith(
            isScanning: false,
            errorMessage: 'Bluetooth is turned off. Please enable Bluetooth.',
          ),
        );
        return;
      }

      // --- 3) SCAN FOR PAIRED PRINTERS ---
      final printers = await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('[PrinterService] Found ${printers.length} paired printer(s)');

      if (printers.isEmpty) {
        _updateState(
          _state.copyWith(
            availablePrinters: const <BluetoothInfo>[],
            isScanning: false,
            errorMessage:
                'No paired printers found. Please pair your printer in Bluetooth settings first.',
          ),
        );
        return;
      }

      // Update UI with paired devices
      _updateState(
        _state.copyWith(availablePrinters: printers, isScanning: false),
      );

      // After scanning, check for existing connection
      await checkExistingConnection();
    } catch (e, st) {
      debugPrint('[PrinterService] Error scanning: $e\n$st');
      _updateState(
        _state.copyWith(
          isScanning: false,
          errorMessage: 'Failed to scan for printers: ${e.toString()}',
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
          await _refreshBatteryLevel();
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

    // Check permissions before connecting
    final hasPermissions = await requestBluetoothPermissions();
    if (!hasPermissions) {
      return false;
    }

    // If another printer is already connected, disconnect it first.
    if (_state.isConnected &&
        _state.connectedPrinterAddress != printer.macAdress) {
      debugPrint(
        '[PrinterService] Disconnecting previous printer before connecting ${printer.name}',
      );
      await disconnect();
    }

    // If already connected to the selected printer, no need to reconnect.
    if (_state.isConnected &&
        _state.connectedPrinterAddress == printer.macAdress) {
      debugPrint('[PrinterService] Already connected to ${printer.name}');
      return true;
    }

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

        await _refreshBatteryLevel();
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

      _updateState(
        _state.copyWith(clearConnectedAddress: true, clearBatteryLevel: true),
      );

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

      // Check permissions first
      final hasPermissions = await requestBluetoothPermissions();
      if (!hasPermissions) {
        debugPrint('[PrinterService] Auto-connect failed: no permissions');
        return false;
      }

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
        _updateState(
          _state.copyWith(clearConnectedAddress: true, clearBatteryLevel: true),
        );
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
        await _refreshBatteryLevel();
      }
    } catch (e) {
      debugPrint('[PrinterService] Error verifying connection: $e');
    }
  }

  /// Refresh connected printer battery level.
  Future<void> _refreshBatteryLevel() async {
    if (!_state.isConnected) return;

    try {
      final batteryLevel = await PrintBluetoothThermal.batteryLevel;
      if (batteryLevel >= 0) {
        _updateState(_state.copyWith(batteryLevel: batteryLevel));
      }
    } catch (e) {
      debugPrint('[PrinterService] Error refreshing battery level: $e');
    }
  }

  /// Update state and notify listeners
  void _updateState(PrinterState newState) {
    _state = newState;
    // Sync connection status with PrinterConnectionService
    PrinterConnectionService.instance.updateConnectionStatus(
      newState.isConnected,
    );
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
