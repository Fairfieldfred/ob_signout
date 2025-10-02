import 'dart:async';

import 'package:flutter/material.dart';

import '../services/nearby_service_http.dart';
import '../services/share_service.dart';
import 'import_preview_screen.dart';

class NearbyReceiveScreen extends StatefulWidget {
  const NearbyReceiveScreen({super.key});

  @override
  State<NearbyReceiveScreen> createState() => _NearbyReceiveScreenState();
}

class _NearbyReceiveScreenState extends State<NearbyReceiveScreen> {
  final NearbyTransferServiceHttp _nearbyService = NearbyTransferServiceHttp();
  StreamSubscription<List<DiscoveredDevice>>? _devicesSubscription;
  StreamSubscription<NearbyDeviceState>? _stateSubscription;

  List<DiscoveredDevice> _devices = [];
  NearbyDeviceState _state = NearbyDeviceState.idle;
  bool _isInitialized = false;
  String? _errorMessage;
  String _displayName = 'Unknown Device';

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to show dialog after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNearby();
    });
  }

  Future<void> _initializeNearby() async {
    try {
      // Get display name from user
      final name = await _showNameDialog();
      if (name == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
      if (!mounted) return;

      setState(() {
        _displayName = name;
      });

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

      // Start browsing for devices
      await _nearbyService.startBrowsing(_displayName);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Receive Patient Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your name to identify this device:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'e.g., Dr. Smith',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return result;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching data...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Fetch data from device
      final jsonData = await _nearbyService.fetchDataFromDevice(device);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (jsonData != null) {
        await _handleReceivedData(jsonData);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleReceivedData(String jsonData) async {
    try {
      final importResult = ShareService.parseObsData(jsonData);

      if (!importResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Invalid data received'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Navigate to import preview
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImportPreviewScreen(importResult: importResult),
          ),
        );

        if (result == true && mounted) {
          // Successfully imported, go back
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process received data: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive via Nearby'),
        centerTitle: true,
      ),
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
                    '• Both devices must be on the same WiFi network\n'
                    '• The sending device must have "Send via Nearby" open\n'
                    '• Discovered devices will appear below\n'
                    '• Tap "Connect" to receive the data',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildDeviceList(theme)),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (_state) {
      case NearbyDeviceState.browsing:
        statusText = 'Searching for devices...';
        statusIcon = Icons.search;
        statusColor = theme.colorScheme.primary;
        break;
      case NearbyDeviceState.connected:
        statusText = 'Downloading data...';
        statusIcon = Icons.download;
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
        child: Row(
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
                    'Visible as: $_displayName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(ThemeData theme) {
    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices_other,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure the sending device has opened the "Send via Nearby" screen and both devices are on the same WiFi network.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceCard(device, theme);
      },
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.phone_android,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${device.host}:${device.port}',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _connectToDevice(device),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Connect'),
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
