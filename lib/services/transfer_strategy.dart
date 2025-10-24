import '../models/patient.dart';

/// Represents different methods for transferring patient data between devices.
enum TransferMethod {
  /// iOS native sharing via UIActivityViewController (includes AirDrop)
  airdrop('AirDrop', 'Share via AirDrop to nearby iOS devices'),

  /// Android native sharing via Intent (includes Nearby Share)
  nearbyShare('Nearby Share', 'Share via Nearby Share to nearby Android devices'),

  /// WiFi-based transfer using mDNS and HTTP
  wifi('WiFi Transfer', 'Share over local WiFi network (works cross-platform)'),

  /// Bluetooth Low Energy transfer (future implementation)
  bluetooth('Bluetooth', 'Share via Bluetooth (offline, slower)');

  const TransferMethod(this.displayName, this.description);

  final String displayName;
  final String description;

  /// Returns true if this method works on the current platform.
  bool get isAvailableOnPlatform {
    // This will be implemented properly in TransferManager
    // using Platform.isIOS/Platform.isAndroid
    return true;
  }
}

/// Progress information for an ongoing transfer.
class TransferProgress {
  final TransferMethod method;
  final TransferState state;
  final int bytesTransferred;
  final int totalBytes;
  final String? statusMessage;
  final String? errorMessage;

  const TransferProgress({
    required this.method,
    required this.state,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.statusMessage,
    this.errorMessage,
  });

  double get percentComplete {
    if (totalBytes == 0) return 0.0;
    return (bytesTransferred / totalBytes) * 100;
  }

  bool get isComplete => state == TransferState.completed;
  bool get hasError => state == TransferState.error;

  TransferProgress copyWith({
    TransferMethod? method,
    TransferState? state,
    int? bytesTransferred,
    int? totalBytes,
    String? statusMessage,
    String? errorMessage,
  }) {
    return TransferProgress(
      method: method ?? this.method,
      state: state ?? this.state,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Represents the current state of a transfer operation.
enum TransferState {
  idle,
  preparing,
  advertising,
  browsing,
  connecting,
  transferring,
  completed,
  cancelled,
  error,
}

/// Result of a transfer operation.
class TransferResult {
  final bool success;
  final String? errorMessage;
  final TransferMethod method;

  const TransferResult({
    required this.success,
    required this.method,
    this.errorMessage,
  });

  factory TransferResult.success(TransferMethod method) {
    return TransferResult(success: true, method: method);
  }

  factory TransferResult.error(TransferMethod method, String errorMessage) {
    return TransferResult(
      success: false,
      method: method,
      errorMessage: errorMessage,
    );
  }
}

/// Abstract strategy for transferring patient data.
///
/// Different implementations handle platform-specific transfer methods
/// like AirDrop, Nearby Share, WiFi, and Bluetooth.
abstract class TransferStrategy {
  /// Returns true if this transfer method is available on the current device.
  Future<bool> isAvailable();

  /// Sends patient data to another device.
  ///
  /// [patients] List of patients to transfer
  /// [senderName] Name of the person sending the data
  /// [notes] Optional additional notes to include
  Future<TransferResult> send({
    required List<Patient> patients,
    required String senderName,
    String? notes,
  });

  /// Receives patient data from another device.
  ///
  /// Returns null if the operation was cancelled or failed.
  Future<String?> receive();

  /// Stream of transfer progress updates.
  Stream<TransferProgress> get progressStream;

  /// Cancels an ongoing transfer operation.
  Future<void> cancel();

  /// Cleans up resources when the strategy is no longer needed.
  Future<void> dispose();

  /// Returns the transfer method this strategy implements.
  TransferMethod get method;
}
