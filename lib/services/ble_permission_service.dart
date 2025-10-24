import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing Bluetooth Low Energy permissions.
///
/// Handles platform-specific permission requests for iOS and Android,
/// including Android 12+ (API 31+) new Bluetooth permissions.
class BlePermissionService {
  static final BlePermissionService _instance = BlePermissionService._internal();

  factory BlePermissionService() => _instance;

  BlePermissionService._internal();

  /// Requests all necessary BLE permissions for the current platform.
  ///
  /// Returns true if all permissions are granted, false otherwise.
  Future<BlePermissionResult> requestPermissions() async {
    if (Platform.isIOS) {
      return await _requestIOSPermissions();
    } else if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    }

    return BlePermissionResult(
      granted: false,
      message: 'Bluetooth permissions not supported on this platform',
    );
  }

  /// Checks if all necessary BLE permissions are granted.
  Future<bool> checkPermissions() async {
    if (Platform.isIOS) {
      // iOS handles permissions automatically on first use via flutter_blue_plus
      // Always return true and let the system handle it
      return true;
    } else if (Platform.isAndroid) {
      return await _checkAndroidPermissions();
    }

    return false;
  }

  Future<BlePermissionResult> _requestIOSPermissions() async {
    // iOS handles Bluetooth permissions automatically when BLE is first used
    // The system will prompt automatically via flutter_blue_plus
    // We just need to ensure the app has the proper Info.plist entries

    // On iOS, we can't pre-request Bluetooth permissions like on Android
    // The permission dialog appears automatically when scanning/advertising starts
    // So we just return success here and let flutter_blue_plus handle it
    return BlePermissionResult(
      granted: true,
      message: 'iOS will prompt for Bluetooth permission when needed',
    );
  }

  Future<BlePermissionResult> _requestAndroidPermissions() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 31) {
      // Android 12+ (API 31+)
      return await _requestAndroid12Permissions();
    } else {
      // Android 6-11 (API 23-30)
      return await _requestLegacyAndroidPermissions();
    }
  }

  Future<BlePermissionResult> _requestAndroid12Permissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    final statuses = await permissions.request();

    final allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

    if (allGranted) {
      return BlePermissionResult(
        granted: true,
        message: 'Bluetooth permissions granted',
      );
    }

    // Check if any are permanently denied
    final anyPermanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied,
    );

    if (anyPermanentlyDenied) {
      return BlePermissionResult(
        granted: false,
        message: 'Bluetooth permissions denied. Please enable them in Settings:\n'
            '• Nearby devices (Bluetooth Scan)\n'
            '• Bluetooth Advertise\n'
            '• Bluetooth Connect',
        shouldOpenSettings: true,
      );
    }

    return BlePermissionResult(
      granted: false,
      message: 'Bluetooth permissions are required for offline data sharing',
    );
  }

  Future<BlePermissionResult> _requestLegacyAndroidPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Required for BLE scanning on Android < 12
    ];

    final statuses = await permissions.request();

    final allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

    if (allGranted) {
      return BlePermissionResult(
        granted: true,
        message: 'Bluetooth and location permissions granted',
      );
    }

    // Check if any are permanently denied
    final anyPermanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied,
    );

    if (anyPermanentlyDenied) {
      return BlePermissionResult(
        granted: false,
        message: 'Bluetooth permissions denied. Please enable them in Settings:\n'
            '• Bluetooth\n'
            '• Location (required for Bluetooth scanning)',
        shouldOpenSettings: true,
      );
    }

    return BlePermissionResult(
      granted: false,
      message: 'Bluetooth and location permissions are required for offline data sharing.\n'
          '(Location is only used for Bluetooth device discovery, not location tracking)',
    );
  }

  Future<bool> _checkAndroidPermissions() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 31) {
      final scan = await Permission.bluetoothScan.status;
      final advertise = await Permission.bluetoothAdvertise.status;
      final connect = await Permission.bluetoothConnect.status;

      return (scan.isGranted || scan.isLimited) &&
             (advertise.isGranted || advertise.isLimited) &&
             (connect.isGranted || connect.isLimited);
    } else {
      final bluetooth = await Permission.bluetooth.status;
      final location = await Permission.locationWhenInUse.status;

      return (bluetooth.isGranted || bluetooth.isLimited) &&
             (location.isGranted || location.isLimited);
    }
  }

  /// Opens the app settings page where the user can manually grant permissions.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

/// Result of a BLE permission request.
class BlePermissionResult {
  final bool granted;
  final String message;
  final bool shouldOpenSettings;

  const BlePermissionResult({
    required this.granted,
    required this.message,
    this.shouldOpenSettings = false,
  });
}
