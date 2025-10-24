import 'dart:async';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/ble_transfer_strategy.dart';
import '../services/transfer_strategy.dart';

/// Screen for sending patient data via Bluetooth LE.
class BleTransferScreen extends StatefulWidget {
  final List<Patient> patients;
  final String senderName;

  const BleTransferScreen({
    super.key,
    required this.patients,
    required this.senderName,
  });

  @override
  State<BleTransferScreen> createState() => _BleTransferScreenState();
}

class _BleTransferScreenState extends State<BleTransferScreen> {
  final BleTransferStrategy _bleStrategy = BleTransferStrategy();
  StreamSubscription<TransferProgress>? _progressSubscription;

  TransferState _state = TransferState.idle;
  String _statusMessage = '';
  int _bytesTransferred = 0;
  int _totalBytes = 0;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  Future<void> _initializeBle() async {
    try {
      // Subscribe to progress updates
      _progressSubscription = _bleStrategy.progressStream.listen((progress) {
        debugPrint('[BLE Transfer Screen] Progress update: state=${progress.state}, message=${progress.statusMessage}');
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
            } else if (progress.state == TransferState.completed) {
              debugPrint('[BLE Transfer Screen] Transfer completed, calling _showSuccessAndClose');
              _showSuccessAndClose();
            }
          });
        }
      });

      // Start advertising
      final result = await _bleStrategy.send(
        patients: widget.patients,
        senderName: widget.senderName,
        notes: 'Bluetooth transfer - ${DateTime.now()}',
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isInitialized = true;
        });
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
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

  void _showSuccessAndClose() {
    if (_isClosing) {
      debugPrint('[BLE Transfer Screen] Already closing, ignoring duplicate call');
      return;
    }
    _isClosing = true;
    debugPrint('[BLE Transfer Screen] _showSuccessAndClose called, waiting 2 seconds...');
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('[BLE Transfer Screen] 2 seconds elapsed, mounted=$mounted');
      if (mounted) {
        debugPrint('[BLE Transfer Screen] Popping navigator');
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
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
          title: const Text('Send via Bluetooth'),
          centerTitle: true,
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_errorMessage != null) {
      return _buildErrorView(theme);
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusIcon(theme),
            const SizedBox(height: 32),
            _buildStatusText(theme),
            const SizedBox(height: 32),
            _buildProgressIndicator(theme),
            const SizedBox(height: 48),
            _buildInstructions(theme),
            const SizedBox(height: 24),
            _buildCancelButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    IconData icon;
    Color color;

    switch (_state) {
      case TransferState.advertising:
        icon = Icons.bluetooth_searching;
        color = theme.colorScheme.primary;
        break;
      case TransferState.connecting:
        icon = Icons.bluetooth_connected;
        color = theme.colorScheme.primary;
        break;
      case TransferState.transferring:
        icon = Icons.sync;
        color = theme.colorScheme.primary;
        break;
      case TransferState.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TransferState.error:
        icon = Icons.error;
        color = theme.colorScheme.error;
        break;
      default:
        icon = Icons.bluetooth;
        color = theme.colorScheme.primary;
    }

    return Icon(
      icon,
      size: 80,
      color: color,
    );
  }

  Widget _buildStatusText(ThemeData theme) {
    return Column(
      children: [
        Text(
          _getStateTitle(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _statusMessage,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getStateTitle() {
    switch (_state) {
      case TransferState.advertising:
        return 'Advertising...';
      case TransferState.connecting:
        return 'Connecting...';
      case TransferState.transferring:
        return 'Transferring...';
      case TransferState.completed:
        return 'Transfer Complete!';
      case TransferState.error:
        return 'Transfer Failed';
      default:
        return 'Preparing...';
    }
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    if (_state == TransferState.transferring && _totalBytes > 0) {
      final progress = _bytesTransferred / _totalBytes;
      return Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatBytes(_bytesTransferred)} / ${_formatBytes(_totalBytes)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    if (_state == TransferState.advertising || _state == TransferState.connecting) {
      return const CircularProgressIndicator();
    }

    return const SizedBox.shrink();
  }

  Widget _buildInstructions(ThemeData theme) {
    if (_state == TransferState.advertising) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onPrimaryContainer,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Waiting for receiver...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '1. On the receiving device, go to "Receive Patient Data"\n'
              '2. Select "Receive via Bluetooth"\n'
              '3. Select this device from the list\n'
              '4. Keep both devices within 30 feet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCancelButton(ThemeData theme) {
    if (_state == TransferState.completed) {
      return ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Done'),
      );
    }

    return OutlinedButton(
      onPressed: () async {
        await _bleStrategy.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: const Text('Cancel Transfer'),
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
              'Transfer Failed',
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
