import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/patient.dart';

enum NearbyDeviceState {
  idle,
  advertising,
  browsing,
  connected,
  error,
}

class NearbyDevice {
  final Device device;
  final bool isConnected;

  NearbyDevice({
    required this.device,
    required this.isConnected,
  });
}

class NearbyTransferService {
  static final NearbyTransferService _instance = NearbyTransferService._internal();
  NearbyService? _nearbyService;

  final _devicesController = StreamController<List<NearbyDevice>>.broadcast();
  final _stateController = StreamController<NearbyDeviceState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  StreamSubscription? _stateSubscription;
  StreamSubscription? _dataSubscription;

  List<Device> _devices = [];

  NearbyDeviceState _currentState = NearbyDeviceState.idle;

  factory NearbyTransferService() {
    return _instance;
  }

  NearbyTransferService._internal();

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  Stream<NearbyDeviceState> get stateStream => _stateController.stream;
  Stream<String> get messageStream => _messageController.stream;

  NearbyDeviceState get currentState => _currentState;
  List<NearbyDevice> get devices => _devices.map((d) => NearbyDevice(
    device: d,
    isConnected: d.state == SessionState.connected,
  )).toList();

  Future<void> initialize() async {
    if (_nearbyService != null) {
      return;
    }

    _nearbyService = NearbyService();

    String devInfo = 'Unknown Device';
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        devInfo = androidInfo.model;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        devInfo = iosInfo.localizedModel;
      }
    } catch (e) {
      devInfo = 'OB SignOut Device';
    }

    await _nearbyService!.init(
      serviceType: 'obSignout',
      deviceName: devInfo,
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) {
        // Service started callback
      },
    );

    _stateSubscription = _nearbyService!.stateChangedSubscription(callback: (devicesList) {
      _devices = devicesList;
      _devicesController.add(devices);

      // Update state based on connections
      final hasConnected = devicesList.any((d) => d.state == SessionState.connected);
      if (hasConnected && _currentState != NearbyDeviceState.connected) {
        _updateState(NearbyDeviceState.connected);
      }
    });

    _dataSubscription = _nearbyService!.dataReceivedSubscription(callback: (data) {
      _handleReceivedData(data);
    });
  }

  Future<void> startAdvertising(String displayName) async {
    try {
      _updateState(NearbyDeviceState.advertising);
      await _nearbyService?.stopBrowsingForPeers();
      await _nearbyService?.stopAdvertisingPeer();
      await Future.delayed(const Duration(milliseconds: 200));
      await _nearbyService?.startAdvertisingPeer();
      await _nearbyService?.startBrowsingForPeers();
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    }
  }

  Future<void> startBrowsing(String displayName) async {
    try {
      _updateState(NearbyDeviceState.browsing);
      await _nearbyService?.stopBrowsingForPeers();
      await _nearbyService?.stopAdvertisingPeer();
      await Future.delayed(const Duration(milliseconds: 200));
      await _nearbyService?.startBrowsingForPeers();
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    }
  }

  Future<void> connectToDevice(Device device) async {
    try {
      await _nearbyService?.invitePeer(
        deviceID: device.deviceId,
        deviceName: device.deviceName,
      );
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    }
  }

  Future<void> sendPatientData({
    required String deviceId,
    required List<Patient> patients,
    required String senderName,
    String? notes,
  }) async {
    try {
      final data = {
        'version': '1.0',
        'appName': 'OB Sign-Out',
        'exportDate': DateTime.now().toIso8601String(),
        'senderName': senderName,
        'notes': notes ?? '',
        'patientCount': patients.length,
        'patients': patients.map((p) => p.toJson()).toList(),
      };

      final jsonString = jsonEncode(data);

      await _nearbyService?.sendMessage(
        deviceId,
        jsonString,
      );
    } catch (e) {
      rethrow;
    }
  }

  void _handleReceivedData(dynamic data) {
    try {
      if (data is String) {
        _messageController.add(data);
      } else if (data is Map) {
        // The data might come as a map with message content
        final message = data['message'] ?? data['data'];
        if (message != null) {
          _messageController.add(message.toString());
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _updateState(NearbyDeviceState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> disconnect(String deviceId) async {
    try {
      await _nearbyService?.disconnectPeer(deviceID: deviceId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopAll() async {
    try {
      await _nearbyService?.stopBrowsingForPeers();
      await _nearbyService?.stopAdvertisingPeer();
      _devices.clear();
      _updateState(NearbyDeviceState.idle);
      _devicesController.add([]);
    } catch (e) {
      // Ignore errors on stop
    }
  }

  void dispose() {
    stopAll();
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    _devicesController.close();
    _stateController.close();
    _messageController.close();
  }
}
