import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/patient.dart';
import 'ble_permission_service.dart';
import 'ble_peripheral_channel.dart';
import 'ble_protocol.dart';
import 'share_service.dart';
import 'transfer_strategy.dart';

/// Discovered BLE device for patient data transfer.
class DiscoveredBleDevice {
  final BluetoothDevice device;
  final String displayName;
  final int rssi;

  const DiscoveredBleDevice({
    required this.device,
    required this.displayName,
    required this.rssi,
  });
}

/// Transfer strategy using Bluetooth Low Energy.
///
/// Implements cross-platform offline transfers between iOS and Android.
/// Uses chunked data transfer with acknowledgments for reliability.
class BleTransferStrategy implements TransferStrategy {
  final _progressController = StreamController<TransferProgress>.broadcast();
  final _devicesController = StreamController<List<DiscoveredBleDevice>>.broadcast();
  final _permissionService = BlePermissionService();
  final _peripheralChannel = BlePeripheralChannel();

  final List<DiscoveredBleDevice> _discoveredDevices = [];
  final List<BleDataChunk> _receivedChunks = [];

  String? _deviceName;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _peripheralStateSubscription;
  StreamSubscription? _peripheralErrorSubscription;
  StreamSubscription? _peripheralCompleteSubscription;
  BluetoothDevice? _connectedDevice;

  // For peripheral (sender) mode
  List<BleDataChunk>? _chunksToSend;
  BleTransferMetadata? _metadata;
  bool _isAdvertising = false;
  DateTime? _transferStartTime;

  BleTransferStrategy() {
    _setupPeripheralListeners();
  }

  void _setupPeripheralListeners() {
    debugPrint('[BLE Strategy] Setting up peripheral listeners');
    _peripheralStateSubscription = _peripheralChannel.stateStream.listen((state) {
      debugPrint('[BLE Strategy] State stream received: $state');
      _handlePeripheralState(state);
    });

    _peripheralErrorSubscription = _peripheralChannel.errorStream.listen((error) {
      debugPrint('[BLE Strategy] Error stream received: $error');
      _updateProgress(TransferState.error, error);
    });

    _peripheralCompleteSubscription = _peripheralChannel.transferCompleteStream.listen((_) {
      debugPrint('[BLE Strategy] Transfer complete stream received');
      _updateProgress(TransferState.completed, 'Transfer complete!');
      // Stop advertising to clean up the peripheral manager
      stopAdvertising();
    });
    debugPrint('[BLE Strategy] Peripheral listeners setup complete');
  }

  void _handlePeripheralState(String state) {
    debugPrint('[BLE Strategy] Handling peripheral state: $state');
    switch (state) {
      case 'advertising':
        _isAdvertising = true;
        _transferStartTime = null;
        _updateProgress(TransferState.advertising, 'Advertising... waiting for connection');
        break;
      case 'connected':
        _updateProgress(TransferState.connecting, 'Device connected');
        break;
      case 'subscribed':
        _transferStartTime = DateTime.now();
        _updateProgress(TransferState.transferring, 'Starting transfer...');
        debugPrint('[BLE Send] ====== TRANSFER STARTED ======');
        debugPrint('[BLE Send] Transfer start time: ${_transferStartTime!.toIso8601String()}');
        break;
      case 'complete':
        if (_transferStartTime != null && _metadata != null) {
          final duration = DateTime.now().difference(_transferStartTime!);
          final bytesPerSecond = (_metadata!.totalBytes / duration.inMilliseconds * 1000).round();
          debugPrint('[BLE Send] ====== TRANSFER COMPLETE ======');
          debugPrint('[BLE Send] Total bytes sent: ${_metadata!.totalBytes}');
          debugPrint('[BLE Send] Total chunks sent: ${_metadata!.totalChunks}');
          debugPrint('[BLE Send] Transfer duration: ${duration.inSeconds}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s');
          debugPrint('[BLE Send] Average speed: ${_formatBytes(bytesPerSecond)}/s');
          debugPrint('[BLE Send] ==============================');
        }
        _updateProgress(TransferState.completed, 'Transfer complete!');
        // Stop advertising to clean up the peripheral manager
        stopAdvertising();
        _transferStartTime = null;
        break;
      case 'stopped':
        _isAdvertising = false;
        _transferStartTime = null;
        _updateProgress(TransferState.idle, 'Stopped advertising');
        break;
    }
  }

  @override
  TransferMethod get method => TransferMethod.bluetooth;

  @override
  Future<bool> isAvailable() async {
    try {
      // Check if Bluetooth is supported
      if (Platform.isAndroid) {
        final isSupported = await FlutterBluePlus.isSupported;
        if (!isSupported) return false;
      }

      // On iOS, don't check state here - permission dialog appears when scanning starts
      // Checking state too early can cause "unauthorized" error before user sees permission dialog
      if (Platform.isIOS) {
        return true; // Let flutter_blue_plus handle permission prompting
      }

      // Check if Bluetooth is turned on (Android only)
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<TransferResult> send({
    required List<Patient> patients,
    required String senderName,
    String? notes,
  }) async {
    try {
      _updateProgress(TransferState.preparing, 'Checking Bluetooth permissions...');

      // Check/request permissions
      final permissionResult = await _permissionService.requestPermissions();
      if (!permissionResult.granted) {
        return TransferResult.error(method, permissionResult.message);
      }

      // Check if Bluetooth is available
      final available = await isAvailable();
      if (!available) {
        return TransferResult.error(
          method,
          'Bluetooth is not available. Please turn on Bluetooth in your device settings.',
        );
      }

      // Get device name
      _deviceName = await _getDeviceName();

      // Prepare data
      _updateProgress(TransferState.preparing, 'Preparing patient data...');
      final jsonData = ShareService.createObsFileData(patients, senderName, notes);

      // Debug: Log raw data size
      debugPrint('[BLE Transfer] ====== DATA PREPARATION ======');
      debugPrint('[BLE Transfer] Raw JSON size: ${jsonData.length} characters');
      debugPrint('[BLE Transfer] Raw JSON bytes: ${utf8.encode(jsonData).length} bytes');

      // Create chunks
      _chunksToSend = BleDataChunker.chunkData(jsonData);
      _metadata = BleTransferMetadata.fromJsonData(
        _deviceName!,
        senderName,
        jsonData,
      );

      // Debug: Log chunk information
      debugPrint('[BLE Transfer] Total chunks: ${_chunksToSend!.length}');
      debugPrint('[BLE Transfer] Max chunk size: ${BleProtocol.maxChunkDataSize} bytes');

      // Calculate and log chunk size statistics
      final chunkSizes = _chunksToSend!.map((c) => c.data.length).toList();
      final avgChunkSize = chunkSizes.reduce((a, b) => a + b) / chunkSizes.length;
      final minChunkSize = chunkSizes.reduce((a, b) => a < b ? a : b);
      final maxChunkSize = chunkSizes.reduce((a, b) => a > b ? a : b);

      debugPrint('[BLE Transfer] Average chunk size: ${avgChunkSize.toStringAsFixed(1)} bytes');
      debugPrint('[BLE Transfer] Min chunk size: $minChunkSize bytes');
      debugPrint('[BLE Transfer] Max chunk size: $maxChunkSize bytes');
      debugPrint('[BLE Transfer] ==============================');

      _updateProgress(
        TransferState.preparing,
        'Ready to send ${_chunksToSend!.length} chunks (${_formatBytes(_metadata!.totalBytes)})',
      );

      // Start advertising via native peripheral
      await _startAdvertising();

      return TransferResult.success(method);
    } catch (e) {
      _updateProgress(TransferState.error, 'Failed to prepare transfer: $e');
      return TransferResult.error(method, 'Failed to prepare transfer: $e');
    }
  }

  @override
  Future<String?> receive() async {
    try {
      _updateProgress(TransferState.preparing, 'Checking Bluetooth permissions...');

      // Check/request permissions
      final permissionResult = await _permissionService.requestPermissions();
      if (!permissionResult.granted) {
        _updateProgress(TransferState.error, permissionResult.message);
        return null;
      }

      // Check if Bluetooth is available
      final available = await isAvailable();
      if (!available) {
        _updateProgress(
          TransferState.error,
          'Bluetooth is not available. Please turn on Bluetooth.',
        );
        return null;
      }

      // Start scanning
      await startScanning();

      // Note: Actual connection/receiving happens when user selects a device
      return null;
    } catch (e) {
      _updateProgress(TransferState.error, 'Failed to start scanning: $e');
      return null;
    }
  }

  /// Waits for Bluetooth adapter to be in a ready state (on).
  /// Returns true if ready, false if timeout or error state.
  Future<bool> _waitForBluetoothReady({required Duration timeout}) async {
    final completer = Completer<bool>();

    StreamSubscription<BluetoothAdapterState>? subscription;

    // Set up timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });

    // Listen for adapter state changes
    subscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint('[BLE] Bluetooth adapter state: $state');

      if (state == BluetoothAdapterState.on) {
        if (!completer.isCompleted) {
          timer.cancel();
          subscription?.cancel();
          completer.complete(true);
        }
      } else if (state == BluetoothAdapterState.off ||
                 state == BluetoothAdapterState.unauthorized) {
        if (!completer.isCompleted) {
          timer.cancel();
          subscription?.cancel();
          completer.complete(false);
        }
      }
      // For 'unknown' or 'unavailable', keep waiting for a definitive state
    });

    return completer.future;
  }

  /// Starts scanning for nearby BLE devices.
  Future<void> startScanning() async {
    try {
      _discoveredDevices.clear();
      _devicesController.add(_discoveredDevices);

      _updateProgress(TransferState.browsing, 'Scanning for nearby devices...');

      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      // Wait for Bluetooth adapter to be ready (especially important on iOS)
      if (Platform.isIOS) {
        _updateProgress(TransferState.browsing, 'Initializing Bluetooth...');

        // Wait for adapter to be ready with timeout
        final ready = await _waitForBluetoothReady(timeout: const Duration(seconds: 5));

        if (!ready) {
          final currentState = await FlutterBluePlus.adapterState.first;
          if (currentState == BluetoothAdapterState.unauthorized) {
            _updateProgress(
              TransferState.error,
              'Bluetooth permission denied. Please enable Bluetooth in Settings → OB SignOut.',
            );
          } else if (currentState == BluetoothAdapterState.off) {
            _updateProgress(
              TransferState.error,
              'Bluetooth is turned off. Please turn on Bluetooth in Settings.',
            );
          } else {
            _updateProgress(
              TransferState.error,
              'Bluetooth failed to initialize. Please try again.',
            );
          }
          return;
        }
      }

      _updateProgress(TransferState.browsing, 'Scanning for nearby devices...');

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        withServices: [Guid(BleProtocol.serviceUuid)],
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          _addDiscoveredDevice(result);
        }
      });
    } catch (e) {
      _updateProgress(TransferState.error, 'Failed to start scanning: $e');
      rethrow;
    }
  }

  void _addDiscoveredDevice(ScanResult result) {
    // Try to get sender name from service data (Android) or platform name (iOS)
    String deviceName = 'Unknown Device';

    // First, try to get sender name from service data (Android sends it this way)
    final serviceData = result.advertisementData.serviceData;
    if (serviceData.isNotEmpty) {
      final serviceUuid = Guid(BleProtocol.serviceUuid);
      final senderNameBytes = serviceData[serviceUuid];
      if (senderNameBytes != null && senderNameBytes.isNotEmpty) {
        try {
          deviceName = String.fromCharCodes(senderNameBytes);
        } catch (e) {
          debugPrint('[BLE] Failed to decode sender name from service data: $e');
        }
      }
    }

    // If we didn't get it from service data, use platform name (iOS sends it this way)
    if (deviceName == 'Unknown Device' && result.device.platformName.isNotEmpty) {
      deviceName = result.device.platformName;
    }

    final discoveredDevice = DiscoveredBleDevice(
      device: result.device,
      displayName: deviceName,
      rssi: result.rssi,
    );

    // Don't add duplicates
    final existingIndex = _discoveredDevices.indexWhere(
      (d) => d.device.remoteId == result.device.remoteId,
    );

    if (existingIndex >= 0) {
      _discoveredDevices[existingIndex] = discoveredDevice;
    } else {
      _discoveredDevices.add(discoveredDevice);
    }

    _devicesController.add(_discoveredDevices);
  }

  /// Stops scanning for BLE devices.
  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Starts advertising as a BLE peripheral.
  Future<void> _startAdvertising() async {
    if (_metadata == null || _chunksToSend == null) {
      throw Exception('No data prepared for advertising');
    }

    _updateProgress(TransferState.advertising, 'Starting advertising...');

    // Convert chunks to bytes
    final chunkBytes = _chunksToSend!.map((chunk) => chunk.toBytes()).toList();

    // Start native peripheral advertising
    await _peripheralChannel.startAdvertising(
      metadata: _metadata!.toBytes(),
      chunks: chunkBytes,
      senderName: _metadata!.senderName,
    );
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    if (_isAdvertising) {
      await _peripheralChannel.stopAdvertising();
      _isAdvertising = false;
      _updateProgress(TransferState.idle, 'Stopped advertising');
    }
  }

  /// Connects to a discovered device and receives data.
  Future<String?> connectAndReceive(DiscoveredBleDevice discoveredDevice) async {
    try {
      _updateProgress(TransferState.connecting, 'Connecting to ${discoveredDevice.displayName}...');

      final device = discoveredDevice.device;
      _connectedDevice = device;

      // Connect to device
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );

      _updateProgress(TransferState.connecting, 'Discovering services...');

      // Discover services
      final services = await device.discoverServices();

      // Find our service
      final service = services.firstWhere(
        (s) => s.uuid == Guid(BleProtocol.serviceUuid),
        orElse: () => throw Exception('OB SignOut service not found'),
      );

      // Find characteristics
      final metadataChar = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(BleProtocol.metadataCharUuid),
      );

      final dataChunkChar = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(BleProtocol.dataChunkCharUuid),
      );

      // Read metadata
      _updateProgress(TransferState.connecting, 'Reading transfer metadata...');
      final metadataBytes = await metadataChar.read();
      final metadata = BleTransferMetadata.fromBytes(Uint8List.fromList(metadataBytes));

      debugPrint('[BLE Receive] ====== RECEIVING DATA ======');
      debugPrint('[BLE Receive] Sender: ${metadata.senderName}');
      debugPrint('[BLE Receive] Device: ${metadata.deviceName}');
      debugPrint('[BLE Receive] Total bytes expected: ${metadata.totalBytes}');
      debugPrint('[BLE Receive] Total chunks expected: ${metadata.totalChunks}');
      debugPrint('[BLE Receive] Starting transfer...');

      _updateProgress(
        TransferState.transferring,
        'Receiving ${metadata.totalChunks} chunks from ${metadata.senderName}...',
      );

      // Subscribe to data chunks with retry logic
      // Sometimes the GATT server needs a moment to be ready
      bool subscribed = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!subscribed && retryCount < maxRetries) {
        try {
          debugPrint('[BLE Receive] Attempting to subscribe to notifications (attempt ${retryCount + 1}/$maxRetries)');
          await dataChunkChar.setNotifyValue(true);
          subscribed = true;
          debugPrint('[BLE Receive] Successfully subscribed to notifications');
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            debugPrint('[BLE Receive] Subscribe failed, waiting before retry: $e');
            await Future.delayed(Duration(milliseconds: 500 * retryCount)); // Increasing delay
          } else {
            debugPrint('[BLE Receive] Subscribe failed after $maxRetries attempts: $e');
            rethrow;
          }
        }
      }

      _receivedChunks.clear();
      final completer = Completer<String>();
      final startTime = DateTime.now();

      final subscription = dataChunkChar.onValueReceived.listen((value) {
        try {
          final chunk = BleDataChunk.fromBytes(Uint8List.fromList(value));
          _receivedChunks.add(chunk);

          final bytesReceived = _receivedChunks.fold<int>(0, (sum, c) => sum + c.data.length);
          final progressPercent = (bytesReceived / metadata.totalBytes * 100).toStringAsFixed(1);

          // Debug: Log each chunk received
          debugPrint('[BLE Receive] Chunk ${chunk.chunkIndex + 1}/${chunk.totalChunks} received: ${chunk.data.length} bytes (Progress: $progressPercent%, Total: $bytesReceived/${metadata.totalBytes} bytes)');

          _updateProgress(
            TransferState.transferring,
            'Received chunk ${chunk.chunkIndex + 1}/${chunk.totalChunks}',
            bytesTransferred: bytesReceived,
            totalBytes: metadata.totalBytes,
          );

          // Check if transfer is complete
          if (_receivedChunks.length == metadata.totalChunks) {
            final duration = DateTime.now().difference(startTime);
            final bytesPerSecond = (metadata.totalBytes / duration.inMilliseconds * 1000).round();
            debugPrint('[BLE Receive] ====== TRANSFER COMPLETE ======');
            debugPrint('[BLE Receive] Total bytes received: $bytesReceived');
            debugPrint('[BLE Receive] Total chunks received: ${_receivedChunks.length}');
            debugPrint('[BLE Receive] Transfer duration: ${duration.inSeconds}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s');
            debugPrint('[BLE Receive] Average speed: ${_formatBytes(bytesPerSecond)}/s');
            debugPrint('[BLE Receive] ==============================');

            final jsonData = BleDataChunker.reassembleChunks(_receivedChunks);
            completer.complete(jsonData);
          }
        } catch (e) {
          debugPrint('[BLE Receive] Error processing chunk: $e');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });

      // Wait for transfer to complete or timeout
      final jsonData = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Transfer took too long'),
      );

      await subscription.cancel();

      // Unsubscribe from notifications before disconnecting
      // This triggers the peripheral's didUnsubscribeFrom callback
      debugPrint('[BLE Receive] Unsubscribing from notifications...');
      await dataChunkChar.setNotifyValue(false);

      // Small delay to ensure unsubscribe is processed
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('[BLE Receive] Disconnecting from device...');
      await device.disconnect();

      _updateProgress(TransferState.completed, 'Transfer complete!');

      return jsonData;
    } catch (e) {
      _updateProgress(TransferState.error, 'Transfer failed: $e');
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      rethrow;
    }
  }

  /// Stream of discovered BLE devices.
  Stream<List<DiscoveredBleDevice>> get devicesStream => _devicesController.stream;

  /// Current list of discovered devices.
  List<DiscoveredBleDevice> get devices => List.unmodifiable(_discoveredDevices);

  @override
  Stream<TransferProgress> get progressStream => _progressController.stream;

  @override
  Future<void> cancel() async {
    await stopScanning();
    await stopAdvertising();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _chunksToSend = null;
    _metadata = null;
    _receivedChunks.clear();

    _updateProgress(TransferState.cancelled, 'Transfer cancelled');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[BLE Strategy] Disposing strategy');
    await cancel();

    // Cancel peripheral subscriptions for this instance
    await _peripheralStateSubscription?.cancel();
    await _peripheralErrorSubscription?.cancel();
    await _peripheralCompleteSubscription?.cancel();

    await _progressController.close();
    await _devicesController.close();

    // Do NOT dispose the peripheral channel - it's a singleton
    debugPrint('[BLE Strategy] Dispose complete');
  }

  void _updateProgress(
    TransferState state,
    String message, {
    int? bytesTransferred,
    int? totalBytes,
  }) {
    _progressController.add(TransferProgress(
      method: method,
      state: state,
      statusMessage: message,
      bytesTransferred: bytesTransferred ?? 0,
      totalBytes: totalBytes ?? 0,
    ));
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      }
    } catch (e) {
      // Ignore
    }

    return 'OB SignOut Device';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
