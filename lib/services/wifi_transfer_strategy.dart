import 'dart:async';
import '../models/patient.dart';
import '../services/share_service.dart';
import 'nearby_service_http.dart';
import 'transfer_strategy.dart';

/// Transfer strategy using WiFi and mDNS for device discovery.
///
/// This wraps the existing NearbyTransferServiceHttp to conform to
/// the TransferStrategy interface. Works cross-platform (iOS ↔ Android).
class WiFiTransferStrategy implements TransferStrategy {
  final NearbyTransferServiceHttp _nearbyService;
  final _progressController = StreamController<TransferProgress>.broadcast();

  StreamSubscription<NearbyDeviceState>? _stateSubscription;

  WiFiTransferStrategy() : _nearbyService = NearbyTransferServiceHttp() {
    _setupStateListener();
  }

  void _setupStateListener() {
    _stateSubscription = _nearbyService.stateStream.listen((state) {
      TransferState transferState;
      String? statusMessage;

      switch (state) {
        case NearbyDeviceState.idle:
          transferState = TransferState.idle;
          statusMessage = 'Ready';
          break;
        case NearbyDeviceState.advertising:
          transferState = TransferState.advertising;
          statusMessage = 'Advertising device on network...';
          break;
        case NearbyDeviceState.browsing:
          transferState = TransferState.browsing;
          statusMessage = 'Searching for nearby devices...';
          break;
        case NearbyDeviceState.connected:
          transferState = TransferState.transferring;
          statusMessage = 'Transferring data...';
          break;
        case NearbyDeviceState.error:
          transferState = TransferState.error;
          statusMessage = 'Connection error';
          break;
      }

      _progressController.add(TransferProgress(
        method: method,
        state: transferState,
        statusMessage: statusMessage,
      ));
    });
  }

  @override
  TransferMethod get method => TransferMethod.wifi;

  @override
  Future<bool> isAvailable() async {
    // WiFi transfer is always available
    // (though it requires devices to be on the same network)
    return true;
  }

  @override
  Future<TransferResult> send({
    required List<Patient> patients,
    required String senderName,
    String? notes,
  }) async {
    try {
      await _nearbyService.initialize();

      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.preparing,
        statusMessage: 'Preparing data for WiFi transfer...',
      ));

      // Create JSON data
      final jsonData = ShareService.createObsFileData(
        patients,
        senderName,
        notes,
      );

      // Start advertising
      await _nearbyService.startAdvertising(
        senderName,
        jsonData: jsonData,
      );

      return TransferResult.success(method);
    } catch (e) {
      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.error,
        errorMessage: 'Failed to start WiFi transfer: $e',
      ));

      return TransferResult.error(method, 'Failed to start WiFi transfer: $e');
    }
  }

  @override
  Future<String?> receive() async {
    try {
      await _nearbyService.initialize();

      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.browsing,
        statusMessage: 'Searching for nearby devices...',
      ));

      // Start browsing - this returns immediately
      // The actual device list is available via devicesStream
      await _nearbyService.startBrowsing('Receiver');

      // Note: The actual connection and data fetch happens when
      // the user selects a device from the UI
      return null;
    } catch (e) {
      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.error,
        errorMessage: 'Failed to browse for devices: $e',
      ));

      return null;
    }
  }

  /// Fetches data from a discovered device.
  ///
  /// This is called after the user selects a device from the discovery list.
  Future<String?> fetchFromDevice(DiscoveredDevice device) async {
    try {
      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.connecting,
        statusMessage: 'Connecting to ${device.name}...',
      ));

      final data = await _nearbyService.fetchDataFromDevice(device);

      if (data != null) {
        _progressController.add(TransferProgress(
          method: method,
          state: TransferState.completed,
          statusMessage: 'Transfer complete',
        ));
      }

      return data;
    } catch (e) {
      _progressController.add(TransferProgress(
        method: method,
        state: TransferState.error,
        errorMessage: 'Failed to fetch data: $e',
      ));

      return null;
    }
  }

  /// Returns the stream of discovered devices.
  Stream<List<DiscoveredDevice>> get devicesStream =>
      _nearbyService.devicesStream;

  /// Returns the current list of discovered devices.
  List<DiscoveredDevice> get devices => _nearbyService.devices;

  @override
  Stream<TransferProgress> get progressStream => _progressController.stream;

  @override
  Future<void> cancel() async {
    await _nearbyService.stopAll();

    _progressController.add(TransferProgress(
      method: method,
      state: TransferState.cancelled,
      statusMessage: 'Transfer cancelled',
    ));
  }

  @override
  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await _nearbyService.stopAll();
    _nearbyService.dispose();
    await _progressController.close();
  }
}
