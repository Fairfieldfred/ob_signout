import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_transfer_strategy.dart';
import '../services/share_service.dart';
import '../services/transfer_strategy.dart';
import 'import_preview_screen.dart';

/// Screen for receiving patient data via Bluetooth LE.
class BleReceiveScreen extends StatefulWidget {
  const BleReceiveScreen({super.key});

  @override
  State<BleReceiveScreen> createState() => _BleReceiveScreenState();
}

class _BleReceiveScreenState extends State<BleReceiveScreen> {
  final BleTransferStrategy _bleStrategy = BleTransferStrategy();
  StreamSubscription<List<DiscoveredBleDevice>>? _devicesSubscription;
  StreamSubscription<TransferProgress>? _progressSubscription;

  List<DiscoveredBleDevice> _devices = [];
  TransferState _state = TransferState.idle;
  String _statusMessage = '';
  int _bytesTransferred = 0;
  int _totalBytes = 0;
  bool _isScanning = false;
  String? _errorMessage;
  DiscoveredBleDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  Future<void> _initializeBle() async {
    try {
      // Subscribe to device discoveries
      _devicesSubscription = _bleStrategy.devicesStream.listen((devices) {
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      });

      // Subscribe to progress updates
      _progressSubscription = _bleStrategy.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _state = progress.state;
            _statusMessage = progress.statusMessage ?? '';
            _bytesTransferred = progress.bytesTransferred;
            _totalBytes = progress.totalBytes;

            if (progress.state == TransferState.error) {
              _errorMessage = progress.statusMessage;
              if (_errorMessage == null || _errorMessage!.isEmpty) {
                _errorMessage = 'Unknown error';
              }
              _selectedDevice = null;
            }
          });
        }
      });

      // Start scanning
      await _bleStrategy.receive();

      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _connectToDevice(DiscoveredBleDevice device) async {
    try {
      setState(() {
        _selectedDevice = device;
        _state = TransferState.connecting;
      });

      final jsonData = await _bleStrategy.connectAndReceive(device);

      if (!mounted) return;

      if (jsonData != null) {
        // Parse and navigate to import preview
        final result = ShareService.parseObsData(jsonData);
        if (result.success && mounted) {
          await _bleStrategy.stopScanning();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ImportPreviewScreen(
                importResult: result,
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = result.error ?? 'Failed to parse data';
            _selectedDevice = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection failed: $e';
          _selectedDevice = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _progressSubscription?.cancel();
    _bleStrategy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _bleStrategy.cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receive via Bluetooth'),
          centerTitle: true,
          actions: [
            if (_isScanning)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await _bleStrategy.stopScanning();
                  await _bleStrategy.receive();
                },
                tooltip: 'Refresh',
              ),
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_errorMessage != null && _selectedDevice == null) {
      return _buildErrorView(theme);
    }

    if (_selectedDevice != null) {
      return _buildTransferringView(theme);
    }

    return _buildScanningView(theme);
  }

  Widget _buildScanningView(ThemeData theme) {
    return Column(
      children: [
        _buildInstructions(theme),
        const SizedBox(height: 16),
        if (_devices.isEmpty) ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Scanning for nearby devices...',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure the sender has started sharing',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Found ${_devices.length} device(s)',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _buildDeviceCard(theme, device);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceCard(ThemeData theme, DiscoveredBleDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          device.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Signal: ${_getSignalStrength(device.rssi)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _connectToDevice(device),
      ),
    );
  }

  String _getSignalStrength(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  Widget _buildInstructions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Text(
                'How to receive',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Make sure the sender has started sharing via Bluetooth\n'
            '2. Select their device from the list below\n'
            '3. Wait for the transfer to complete\n'
            '4. Keep both devices within 30 feet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferringView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _state == TransferState.completed
                  ? Icons.check_circle
                  : Icons.bluetooth_connected,
              size: 80,
              color: _state == TransferState.completed
                  ? Colors.green
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 32),
            Text(
              _state == TransferState.completed
                  ? 'Transfer Complete!'
                  : 'Receiving Data...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_state == TransferState.transferring && _totalBytes > 0) ...[
              LinearProgressIndicator(
                value: _bytesTransferred / _totalBytes,
                minHeight: 8,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(_bytesTransferred)} / ${_formatBytes(_totalBytes)}',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (_state != TransferState.completed) ...[
              const CircularProgressIndicator(),
            ],
            const SizedBox(height: 32),
            if (_state != TransferState.completed)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDevice = null;
                  });
                },
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializeBle();
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
