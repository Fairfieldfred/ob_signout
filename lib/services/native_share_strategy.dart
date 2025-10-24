import 'dart:async';
import 'dart:io';
import '../models/patient.dart';
import '../services/share_service.dart';
import 'transfer_strategy.dart';

/// Transfer strategy using platform-native sharing capabilities.
///
/// On iOS, this uses UIActivityViewController which includes AirDrop.
/// On Android, this uses the native share Intent which includes Nearby Share.
class NativeShareStrategy implements TransferStrategy {
  final _progressController = StreamController<TransferProgress>.broadcast();
  TransferMethod? _currentMethod;

  @override
  TransferMethod get method {
    if (Platform.isIOS) {
      return TransferMethod.airdrop;
    } else if (Platform.isAndroid) {
      return TransferMethod.nearbyShare;
    }
    throw UnsupportedError('Platform not supported for native sharing');
  }

  @override
  Future<bool> isAvailable() async {
    // Native sharing is always available on iOS and Android
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Future<TransferResult> send({
    required List<Patient> patients,
    required String senderName,
    String? notes,
  }) async {
    try {
      _currentMethod = method;

      _progressController.add(TransferProgress(
        method: _currentMethod!,
        state: TransferState.preparing,
        statusMessage: 'Preparing patient data...',
      ));

      // Use the existing ShareService to create and share the .obs file
      await ShareService.sharePatientData(
        patients: patients,
        senderName: senderName,
        notes: notes,
      );

      // Note: We can't track actual completion since share_plus doesn't
      // provide callbacks. The system share sheet handles everything.
      _progressController.add(TransferProgress(
        method: _currentMethod!,
        state: TransferState.completed,
        statusMessage: Platform.isIOS
            ? 'Share sheet opened. Select AirDrop to share.'
            : 'Share sheet opened. Select Nearby Share to share.',
      ));

      return TransferResult.success(_currentMethod!);
    } catch (e) {
      _progressController.add(TransferProgress(
        method: _currentMethod!,
        state: TransferState.error,
        errorMessage: 'Failed to open share sheet: $e',
      ));

      return TransferResult.error(
        _currentMethod!,
        'Failed to share: $e',
      );
    }
  }

  @override
  Future<String?> receive() async {
    // Native sharing doesn't support receiving directly
    // Files are received via the system and opened with the app
    // This would be handled by share_handler plugin if needed
    throw UnsupportedError(
      'Native share strategy does not support receiving. '
      'Use share_handler plugin or file import instead.',
    );
  }

  @override
  Stream<TransferProgress> get progressStream => _progressController.stream;

  @override
  Future<void> cancel() async {
    // Cannot cancel system share sheet once opened
    _progressController.add(TransferProgress(
      method: _currentMethod ?? method,
      state: TransferState.cancelled,
      statusMessage: 'Transfer cancelled',
    ));
  }

  @override
  Future<void> dispose() async {
    await _progressController.close();
  }
}
