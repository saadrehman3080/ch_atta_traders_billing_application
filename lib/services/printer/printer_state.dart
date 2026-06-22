import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Represents the current state of the printer connection
class PrinterState {
  final List<BluetoothInfo> availablePrinters;
  final bool isScanning;
  final String? connectingPrinterAddress;
  final String? connectedPrinterAddress;
  final int? batteryLevel;
  final String? errorMessage;

  const PrinterState({
    this.availablePrinters = const [],
    this.isScanning = false,
    this.connectingPrinterAddress,
    this.connectedPrinterAddress,
    this.batteryLevel,
    this.errorMessage,
  });

  /// Returns true if any printer is currently being connected
  bool get isAnyPrinterConnecting => connectingPrinterAddress != null;

  /// Returns true if a printer is connected
  bool get isConnected => connectedPrinterAddress != null;

  /// Returns true if there's an error
  bool get hasError => errorMessage != null;

  /// Creates a copy of this state with the given fields replaced
  PrinterState copyWith({
    List<BluetoothInfo>? availablePrinters,
    bool? isScanning,
    String? connectingPrinterAddress,
    String? connectedPrinterAddress,
    int? batteryLevel,
    String? errorMessage,
    bool clearConnectingAddress = false,
    bool clearConnectedAddress = false,
    bool clearBatteryLevel = false,
    bool clearError = false,
  }) {
    return PrinterState(
      availablePrinters: availablePrinters ?? this.availablePrinters,
      isScanning: isScanning ?? this.isScanning,
      connectingPrinterAddress: clearConnectingAddress
          ? null
          : connectingPrinterAddress ?? this.connectingPrinterAddress,
      connectedPrinterAddress: clearConnectedAddress
          ? null
          : connectedPrinterAddress ?? this.connectedPrinterAddress,
      batteryLevel: clearBatteryLevel
          ? null
          : batteryLevel ?? this.batteryLevel,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'PrinterState(printers: ${availablePrinters.length}, '
        'scanning: $isScanning, '
        'connecting: $connectingPrinterAddress, '
        'connected: $connectedPrinterAddress, '
        'error: $errorMessage)';
  }
}
