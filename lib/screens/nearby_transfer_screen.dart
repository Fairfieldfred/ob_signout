import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/nearby_service_http.dart';

class NearbyTransferScreen extends StatefulWidget {
  final List<Patient> patients;
  final String senderName;

  const NearbyTransferScreen({
    super.key,
    required this.patients,
    required this.senderName,
  });

  @override
  State<NearbyTransferScreen> createState() => _NearbyTransferScreenState();
}

class _NearbyTransferScreenState extends State<NearbyTransferScreen> {
  final NearbyTransferServiceHttp _nearbyService = NearbyTransferServiceHttp();
  StreamSubscription<List<DiscoveredDevice>>? _devicesSubscription;
  StreamSubscription<NearbyDeviceState>? _stateSubscription;

  List<DiscoveredDevice> _devices = [];
  NearbyDeviceState _state = NearbyDeviceState.idle;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeNearby();
  }

  Future<void> _initializeNearby() async {
    try {
      // Initialize service
      await _nearbyService.initialize();

      // Subscribe to streams
      _devicesSubscription = _nearbyService.devicesStream.listen((devices) {
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      });

      _stateSubscription = _nearbyService.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _state = state;
          });
        }
      });

      // Prepare JSON data
      final jsonData = _createJsonData();

      // Start advertising
      await _nearbyService.startAdvertising(
        widget.senderName,
        jsonData: jsonData,
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  String _createJsonData() {
    final data = {
      'version': '1.0',
      'appName': 'OB Sign-Out',
      'exportDate': DateTime.now().toIso8601String(),
      'senderName': widget.senderName,
      'notes': 'Nearby Transfer - ${DateTime.now()}',
      'patientCount': widget.patients.length,
      'patients': widget.patients.map((p) => p.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Send via Nearby'), centerTitle: true),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing nearby connections...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStatusCard(theme),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Keep this screen open\n'
                    '2. On the receiving device, open "Receive via Nearby"\n'
                    '3. Both devices must be on the same WiFi network\n'
                    '4. The receiving device will discover this device and can connect to download the data',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (_state) {
      case NearbyDeviceState.advertising:
        statusText = 'Advertising...';
        statusIcon = Icons.broadcast_on_personal;
        statusColor = theme.colorScheme.primary;
        break;
      case NearbyDeviceState.connected:
        statusText = 'Connected';
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case NearbyDeviceState.error:
        statusText = 'Error';
        statusIcon = Icons.error;
        statusColor = theme.colorScheme.error;
        break;
      default:
        statusText = 'Idle';
        statusIcon = Icons.info;
        statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sharing ${widget.patients.length} patient(s) from ${widget.senderName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _stateSubscription?.cancel();
    _nearbyService.stopAll();
    super.dispose();
  }
}
