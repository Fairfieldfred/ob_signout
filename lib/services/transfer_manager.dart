import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/patient.dart';
import 'ble_transfer_strategy.dart';
import 'native_share_strategy.dart';
import 'transfer_strategy.dart';
import 'wifi_transfer_strategy.dart';

/// Manages transfer operations and selects the optimal transfer method.
///
/// This class provides a high-level interface for transferring patient data
/// and automatically recommends the best transfer method based on platform,
/// network availability, and data size.
class TransferManager {
  WiFiTransferStrategy? _wifiStrategy;
  NativeShareStrategy? _nativeStrategy;
  BleTransferStrategy? _bleStrategy;

  /// Returns the appropriate strategy for the given transfer method.
  TransferStrategy getStrategy(TransferMethod method) {
    switch (method) {
      case TransferMethod.airdrop:
      case TransferMethod.nearbyShare:
        _nativeStrategy ??= NativeShareStrategy();
        return _nativeStrategy!;

      case TransferMethod.wifi:
        _wifiStrategy ??= WiFiTransferStrategy();
        return _wifiStrategy!;

      case TransferMethod.bluetooth:
        _bleStrategy ??= BleTransferStrategy();
        return _bleStrategy!;
    }
  }

  /// Recommends the best transfer method for the current context.
  ///
  /// The recommendation algorithm prioritizes:
  /// 1. Same-platform native sharing (AirDrop/Nearby Share) for best UX
  /// 2. WiFi for cross-platform transfers (only if network is available)
  /// 3. Bluetooth if WiFi is unavailable or for offline scenarios
  Future<TransferMethodRecommendation> recommendMethod({
    bool? targetIsIOS,
    bool? targetIsAndroid,
    int? estimatedDataSizeBytes,
  }) async {
    final currentPlatformIsIOS = Platform.isIOS;
    final currentPlatformIsAndroid = Platform.isAndroid;

    // If we know the target platform and it matches ours, use native sharing
    if (targetIsIOS != null && currentPlatformIsIOS && targetIsIOS) {
      return TransferMethodRecommendation(
        method: TransferMethod.airdrop,
        reason: 'Fastest and most reliable for iOS to iOS transfers',
        confidence: RecommendationConfidence.high,
        estimatedTimeSeconds: 5,
      );
    }

    if (targetIsAndroid != null &&
        currentPlatformIsAndroid &&
        targetIsAndroid) {
      return TransferMethodRecommendation(
        method: TransferMethod.nearbyShare,
        reason: 'Fastest and most reliable for Android to Android transfers',
        confidence: RecommendationConfidence.high,
        estimatedTimeSeconds: 5,
      );
    }

    // Check if WiFi is actually available and working
    final hasWorkingWiFi = await _checkWiFiConnectivity();
    final dataSize = estimatedDataSizeBytes ?? 50000; // Default ~50KB

    // If WiFi is available, recommend it for cross-platform transfers
    if (hasWorkingWiFi) {
      final estimatedWiFiSeconds = (dataSize / 10000).ceil(); // ~10KB/sec

      return TransferMethodRecommendation(
        method: TransferMethod.wifi,
        reason: targetIsIOS == null && targetIsAndroid == null
            ? 'Works with all devices on the same WiFi network'
            : 'Best option for cross-platform transfers',
        confidence: RecommendationConfidence.high,
        estimatedTimeSeconds: estimatedWiFiSeconds,
      );
    }

    // If WiFi is not available, recommend Bluetooth
    final estimatedBluetoothSeconds = (dataSize / 5000).ceil(); // ~5KB/sec (slower than WiFi)

    return TransferMethodRecommendation(
      method: TransferMethod.bluetooth,
      reason: hasWorkingWiFi == false
          ? 'WiFi not available - Bluetooth works offline'
          : 'Works without internet connection',
      confidence: RecommendationConfidence.medium,
      estimatedTimeSeconds: estimatedBluetoothSeconds,
    );
  }

  /// Checks if WiFi is connected and working.
  ///
  /// Returns true if connected to WiFi, false otherwise.
  Future<bool> _checkWiFiConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      // Check if connected to WiFi or Ethernet
      final hasWiFiConnection = connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);

      if (!hasWiFiConnection) {
        return false;
      }

      // Additional check: try to verify the connection is actually working
      // by checking if we can reach a local network address
      // This helps catch cases where WiFi is connected but has no internet/local network
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        // If we can't reach the internet, WiFi might still work for local network
        // So we'll still return true if WiFi is connected
        return true;
      }
    } catch (e) {
      // If connectivity check fails, assume WiFi is not available
      return false;
    }
  }

  /// Returns all available transfer methods for the current platform.
  List<TransferMethod> getAvailableMethods() {
    final methods = <TransferMethod>[];

    if (Platform.isIOS) {
      methods.add(TransferMethod.airdrop);
    }

    if (Platform.isAndroid) {
      methods.add(TransferMethod.nearbyShare);
    }

    // WiFi is always available
    methods.add(TransferMethod.wifi);

    // Bluetooth (Phase 2) - available on all platforms
    methods.add(TransferMethod.bluetooth);

    return methods;
  }

  /// Initiates a transfer using the specified method.
  ///
  /// Returns a TransferResult indicating success or failure.
  Future<TransferResult> send({
    required TransferMethod method,
    required List<Patient> patients,
    required String senderName,
    String? notes,
  }) async {
    final strategy = getStrategy(method);

    final isAvailable = await strategy.isAvailable();
    if (!isAvailable) {
      return TransferResult.error(
        method,
        'Transfer method ${method.displayName} is not available on this device',
      );
    }

    return await strategy.send(
      patients: patients,
      senderName: senderName,
      notes: notes,
    );
  }

  /// Starts receiving data using the specified method.
  ///
  /// For WiFi, this starts browsing for nearby devices.
  /// For native sharing, data is received via the system share handler.
  Future<String?> startReceiving(TransferMethod method) async {
    final strategy = getStrategy(method);

    final isAvailable = await strategy.isAvailable();
    if (!isAvailable) {
      return null;
    }

    return await strategy.receive();
  }

  /// Returns the WiFi strategy for accessing device discovery features.
  ///
  /// This is used by the UI to show the list of discovered devices.
  WiFiTransferStrategy? get wifiStrategy => _wifiStrategy;

  /// Returns the BLE strategy for accessing device discovery features.
  ///
  /// This is used by the UI to show the list of discovered BLE devices.
  BleTransferStrategy? get bleStrategy => _bleStrategy;

  /// Cleans up all strategies and releases resources.
  Future<void> dispose() async {
    await _wifiStrategy?.dispose();
    await _nativeStrategy?.dispose();
    await _bleStrategy?.dispose();
    _wifiStrategy = null;
    _nativeStrategy = null;
    _bleStrategy = null;
  }
}

/// Represents a transfer method recommendation with reasoning.
class TransferMethodRecommendation {
  final TransferMethod method;
  final String reason;
  final RecommendationConfidence confidence;
  final int estimatedTimeSeconds;

  const TransferMethodRecommendation({
    required this.method,
    required this.reason,
    required this.confidence,
    required this.estimatedTimeSeconds,
  });

  String get estimatedTimeDisplay {
    if (estimatedTimeSeconds < 10) {
      return 'A few seconds';
    } else if (estimatedTimeSeconds < 60) {
      return '~$estimatedTimeSeconds seconds';
    } else {
      final minutes = (estimatedTimeSeconds / 60).ceil();
      return '~$minutes minute${minutes > 1 ? 's' : ''}';
    }
  }
}

/// Confidence level for a transfer method recommendation.
enum RecommendationConfidence {
  low,
  medium,
  high,
}
