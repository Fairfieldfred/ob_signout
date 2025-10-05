import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:nsd/nsd.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

enum NearbyDeviceState {
  idle,
  advertising,
  browsing,
  connected,
  error,
}

class DiscoveredDevice {
  final String name;
  final String host;
  final int port;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => name.hashCode ^ host.hashCode ^ port.hashCode;
}

class NearbyTransferServiceHttp {
  static final NearbyTransferServiceHttp _instance = NearbyTransferServiceHttp._internal();

  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  final _stateController = StreamController<NearbyDeviceState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  HttpServer? _httpServer;
  Registration? _registration;
  Discovery? _discovery;

  final List<DiscoveredDevice> _discoveredDevices = [];
  NearbyDeviceState _currentState = NearbyDeviceState.idle;

  String? _jsonDataToShare;
  String _deviceName = 'Unknown Device';

  factory NearbyTransferServiceHttp() {
    return _instance;
  }

  NearbyTransferServiceHttp._internal();

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  Stream<NearbyDeviceState> get stateStream => _stateController.stream;
  Stream<String> get messageStream => _messageController.stream;

  NearbyDeviceState get currentState => _currentState;
  List<DiscoveredDevice> get devices => List.unmodifiable(_discoveredDevices);

  Future<void> initialize() async {
    // Get device name
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      }
    } catch (e) {
      _deviceName = 'OB SignOut Device';
    }
  }

  Future<void> startAdvertising(String displayName, {required String jsonData}) async {
    try {
      _updateState(NearbyDeviceState.advertising);

      // Stop any existing services
      await stopAll();

      // Set the data to share AFTER stopping (stopAll clears it)
      _jsonDataToShare = jsonData;

      // Start HTTP server on a random available port
      _httpServer = await shelf_io.serve(
        _handleRequest,
        InternetAddress.anyIPv4,
        0, // Use port 0 to get a random available port
      );

      final port = _httpServer!.port;

      // Register the service via mDNS
      _registration = await register(
        Service(
          name: displayName,
          type: '_obsignout._tcp',
          port: port,
        ),
      );

      _updateState(NearbyDeviceState.advertising);
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    }
  }

  Future<void> startBrowsing(String displayName) async {
    try {
      _updateState(NearbyDeviceState.browsing);

      // Stop any existing discovery
      if (_discovery != null) {
        await stopDiscovery(_discovery!);
        _discovery = null;
      }
      _discoveredDevices.clear();
      _devicesController.add(_discoveredDevices);

      // Start discovering services
      _discovery = await startDiscovery('_obsignout._tcp');

      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          _addDiscoveredDevice(service);
        } else if (status == ServiceStatus.lost) {
          _removeDiscoveredDevice(service);
        }
      });
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    }
  }

  void _addDiscoveredDevice(Service service) async {
    try {
      // Resolve the service to get host and port
      final resolvedService = await resolve(service);

      if (resolvedService.host != null) {
        final device = DiscoveredDevice(
          name: resolvedService.name ?? 'Unknown',
          host: resolvedService.host!,
          port: resolvedService.port ?? 0,
        );

        // Don't add duplicates
        if (!_discoveredDevices.contains(device)) {
          _discoveredDevices.add(device);
          _devicesController.add(_discoveredDevices);
        }
      }
    } catch (e) {
      // Ignore resolution errors
    }
  }

  void _removeDiscoveredDevice(Service service) {
    _discoveredDevices.removeWhere((d) => d.name == service.name);
    _devicesController.add(_discoveredDevices);
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    print('Received request: ${request.method} ${request.url.path}');
    print('Full URL: ${request.url}');
    print('Request URI: ${request.requestedUri}');

    // Handle both with and without leading slash, and empty path
    final path = request.url.path.replaceAll(RegExp(r'^/+'), '');

    if (request.method == 'GET' && path == 'data') {
      if (_jsonDataToShare != null) {
        print('Returning data: ${_jsonDataToShare?.substring(0, 50)}...');
        return shelf.Response.ok(
          _jsonDataToShare,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        );
      } else {
        print('No data available to share');
        return shelf.Response.notFound('No data available');
      }
    }
    print('Path not matched. Returning 404');
    return shelf.Response.notFound('Not found');
  }

  Future<String?> fetchDataFromDevice(DiscoveredDevice device) async {
    try {
      _updateState(NearbyDeviceState.connected);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://${device.host}:${device.port}/data'),
      );
      request.headers.set('Accept', 'application/json');

      final response = await request.close();

      if (response.statusCode == 200) {
        final data = await response.transform(utf8.decoder).join();
        _messageController.add(data);
        return data;
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      _updateState(NearbyDeviceState.error);
      rethrow;
    } finally {
      // Return to browsing state after connection attempt
      if (_currentState != NearbyDeviceState.error) {
        _updateState(NearbyDeviceState.browsing);
      }
    }
  }

  void _updateState(NearbyDeviceState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> stopAll() async {
    try {
      await _httpServer?.close(force: true);
      _httpServer = null;

      if (_registration != null) {
        await unregister(_registration!);
        _registration = null;
      }

      if (_discovery != null) {
        await stopDiscovery(_discovery!);
        _discovery = null;
      }

      _discoveredDevices.clear();
      _jsonDataToShare = null;
      _updateState(NearbyDeviceState.idle);
      _devicesController.add([]);
    } catch (e) {
      // Ignore errors on stop
    }
  }

  void dispose() {
    stopAll();
    _devicesController.close();
    _stateController.close();
    _messageController.close();
  }
}
