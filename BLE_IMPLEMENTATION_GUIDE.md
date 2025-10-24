# Bluetooth LE Cross-Platform Implementation Guide

## Overview

This document captures the critical implementation details, gotchas, and solutions discovered while implementing a robust Bluetooth Low Energy (BLE) data transfer system between iOS and Android devices using Flutter.

### Architecture Summary

- **Flutter Layer**: Dart code using `flutter_blue_plus` for central (scanning) role
- **Native Layer**: Platform-specific code (iOS Swift, Android Kotlin) for peripheral (advertising) role
- **Communication**: Method channels bridge Flutter and native code
- **Data Protocol**: Custom GATT service with chunked data transfer

### Why This Architecture?

`flutter_blue_plus` doesn't support peripheral mode, so we implement:
- **Central role** (scanning/receiving): Use flutter_blue_plus
- **Peripheral role** (advertising/sending): Native iOS/Android code via method channels

---

## Dependencies & Packages

### pubspec.yaml

```yaml
dependencies:
  flutter_blue_plus: ^2.0.0          # BLE central operations
  permission_handler: ^12.0.1        # Runtime permission requests
  device_info_plus: ^11.1.0          # Get device name for display
  connectivity_plus: ^7.0.0          # Check network before recommending WiFi
```

### Why Each Package?

- **flutter_blue_plus**: Best maintained BLE package, but central-only
- **permission_handler**: Simplifies cross-platform permission requests
- **device_info_plus**: Get human-readable device names
- **connectivity_plus**: Verify WiFi is actually working before recommending it

---

## Platform Configuration

### Android Manifest (`android/app/src/main/AndroidManifest.xml`)

```xml
<!-- Bluetooth permissions for Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Bluetooth permissions for Android 6-11 (API 23-30) -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />

<!-- Location permission required for BLE scanning on all Android versions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### ⚠️ CRITICAL ANDROID GOTCHAS

1. **NEVER use `android:usesPermissionFlags="neverForLocation"`**
   - Even though the permission is named `BLUETOOTH_SCAN`, Android still requires location permission for BLE scanning
   - This flag prevents the location permission dialog from appearing
   - Result: Silent failure - no devices discovered, no error message

2. **Location Permission is MANDATORY for BLE scanning**
   - Android links BLE scanning to location services (privacy reasons)
   - Required on ALL Android versions, not just pre-12
   - Use `ACCESS_FINE_LOCATION` for best results

3. **SDK Version-Specific Permissions**
   - Android 12+ (API 31+): Use new granular BLUETOOTH_* permissions
   - Android 6-11 (API 23-30): Use legacy BLUETOOTH and BLUETOOTH_ADMIN
   - Set `maxSdkVersion="30"` on legacy permissions

### iOS Info.plist (`ios/Runner/Info.plist`)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to share patient data with nearby devices when WiFi is unavailable.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to receive patient data from nearby devices when WiFi is unavailable.</string>
```

#### iOS Notes

- iOS handles Bluetooth permissions automatically via system dialogs
- Provide clear, user-friendly descriptions
- Permission prompt appears when first accessing Bluetooth
- No need to check state too early - let flutter_blue_plus handle it

---

## Method Channel Implementation

### Channel Name

```
com.obsignout/ble_peripheral
```

### Flutter Side (`lib/services/ble_peripheral_channel.dart`)

```dart
class BlePeripheralChannel {
  static const MethodChannel _channel =
      MethodChannel('com.obsignout/ble_peripheral');

  static final BlePeripheralChannel _instance = BlePeripheralChannel._internal();
  factory BlePeripheralChannel() => _instance;  // Singleton pattern

  BlePeripheralChannel._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Send to native
  Future<void> startAdvertising({
    required Uint8List metadata,
    required List<Uint8List> chunks,
    required String senderName,  // Added for custom device name
  }) async {
    await _channel.invokeMethod('startAdvertising', {
      'metadata': metadata,
      'chunks': chunks,
      'senderName': senderName,
    });
  }

  // Receive from native
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStateChanged':
        _stateController.add(call.arguments as String);
        break;
      case 'onError':
        _errorController.add(call.arguments as String);
        break;
      case 'onTransferComplete':
        _transferCompleteController.add(null);
        break;
    }
  }
}
```

### iOS Side (`ios/Runner/AppDelegate.swift`)

```swift
class BlePeripheralChannel {
    static let channelName = "com.obsignout/ble_peripheral"
    private var peripheralManager: BlePeripheralManager?
    private var channel: FlutterMethodChannel?

    func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: BlePeripheralChannel.channelName,
            binaryMessenger: registrar.messenger()
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            handleStartAdvertising(call, result: result)
        case "stopAdvertising":
            handleStopAdvertising(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

### Android Side (`android/.../BlePeripheralChannel.kt`)

```kotlin
class BlePeripheralChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL_NAME = "com.obsignout/ble_peripheral"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var peripheralManager: BlePeripheralManager? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> handleStartAdvertising(call.arguments, result)
                "stopAdvertising" -> handleStopAdvertising(result)
                else -> result.notImplemented()
            }
        }
    }
}
```

### ⚠️ METHOD CHANNEL GOTCHAS

1. **Use Singleton Pattern for Channel**
   - Multiple instances = multiple handlers = chaos
   - Use factory constructor to ensure single instance
   - Listeners attached to singleton receive all events

2. **Strong References Required (iOS)**
   ```swift
   @objc class AppDelegate: FlutterAppDelegate {
       private var bleChannel: BlePeripheralChannel?  // Keep strong reference!
   }
   ```
   - Without strong reference, channel gets deallocated
   - Results in "method not found" errors

3. **Thread Safety**
   - iOS: Use `DispatchQueue.main.async` for callbacks to Flutter
   - Android: Use `Handler(Looper.getMainLooper()).post`
   - Method channel calls must be on main thread

4. **Data Serialization**
   - Flutter `Uint8List` → iOS `Data` → iOS `FlutterStandardTypedData`
   - Flutter `Uint8List` → Android `ByteArray`
   - String encoding: Always use UTF-8

---

## Critical Gotchas & Solutions

### 1. Android Location Permission (THE BIG ONE)

#### Problem
```
PlatformException(startScan, Permission android permission. ACCESS_FINE_LOCATION required to scan devices, null, null)
```

#### Root Causes
- Used `android:usesPermissionFlags="neverForLocation"` on `BLUETOOTH_SCAN`
- Used `Permission.location` instead of `Permission.locationWhenInUse`
- Set `maxSdkVersion="30"` on location permissions (removed in final fix)

#### Solution
```xml
<!-- NO neverForLocation flag! -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />

<!-- Keep location permission unrestricted -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

```dart
// In Dart permission request
final permissions = [
  Permission.locationWhenInUse,  // NOT Permission.location
  Permission.bluetoothScan,
  Permission.bluetoothAdvertise,
  Permission.bluetoothConnect,
];
```

### 2. iOS Peripheral Manager Race Conditions

#### Problem
Service setup called multiple times, causing:
- Duplicate advertisements
- State confusion
- Memory leaks

#### Root Cause
```swift
func startAdvertising(metadata: Data, chunks: [Data]) {
    if state == .poweredOn {
        setupService()  // Called here
    }
}

func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    case .poweredOn:
        setupService()  // Also called here!
}
```

#### Solution
```swift
private var isSettingUpService = false

private func setupService() {
    if isSettingUpService {
        return  // Guard against duplicate calls
    }
    isSettingUpService = true
    // ... setup code ...
}

func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    isSettingUpService = false  // Reset flag
    startAdvertisingInternal()
}
```

### 3. Advertisement Name Display

#### Problem
Receiver sees generic device names:
- iOS sender: "iPhone 12" (device model)
- Android sender: "OB SignOut" (hardcoded string)

#### Solution - iOS (Simple)
```swift
let advertisementData: [String: Any] = [
    CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
    CBAdvertisementDataLocalNameKey: senderName  // Use passed sender name
]
```

#### Solution - Android (Requires Workaround)
Android doesn't allow setting device name in advertisement data. Use scan response:

```kotlin
// Advertisement data
val data = AdvertiseData.Builder()
    .setIncludeDeviceName(false)  // Don't use system device name
    .addServiceUuid(ParcelUuid(SERVICE_UUID))
    .build()

// Scan response data with sender name
val scanResponse = AdvertiseData.Builder()
    .setIncludeDeviceName(false)
    .addServiceData(ParcelUuid(SERVICE_UUID), senderName.toByteArray(Charsets.UTF_8))
    .build()

bluetoothLeAdvertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
```

#### Reading on Receiver Side (Flutter)
```dart
void _addDiscoveredDevice(ScanResult result) {
  String deviceName = 'Unknown Device';

  // Try service data first (Android)
  final serviceData = result.advertisementData.serviceData;
  if (serviceData.isNotEmpty) {
    final serviceUuid = Guid(BleProtocol.serviceUuid);
    final senderNameBytes = serviceData[serviceUuid];
    if (senderNameBytes != null && senderNameBytes.isNotEmpty) {
      deviceName = String.fromCharCodes(senderNameBytes);
    }
  }

  // Fallback to platform name (iOS)
  if (deviceName == 'Unknown Device' && result.device.platformName.isNotEmpty) {
    deviceName = result.device.platformName;
  }
}
```

### 4. Stream/Event Flow Issues

#### Problem: Duplicate Completion Events
iOS sends both `onTransferComplete` and `onStateChanged("complete")`, causing:
- Duplicate Navigator.pop() calls
- Black screen (second pop removes too much)

#### Solution
```swift
// In sendNextChunk()
if currentChunkIndex >= chunks.count {
    onTransferComplete?()
    // Don't also send onStateChanged("complete")!
}
```

```dart
// Guard against duplicate calls
bool _isClosing = false;

void _showSuccessAndClose() {
  if (_isClosing) return;  // Ignore duplicates
  _isClosing = true;

  Future.delayed(const Duration(seconds: 2), () {
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  });
}
```

### 5. Logging Best Practices

#### iOS: Use NSLog, Not print
```swift
NSLog("[BLE] Message here")  // Appears in Xcode console
// NOT: print("[BLE] Message")  // Often doesn't appear
```

#### Flutter: Use debugPrint
```dart
debugPrint('[BLE Strategy] Message here');
```

### 6. iOS Permission Checking Timing

#### Problem
Checking `FlutterBluePlus.adapterState` too early causes "unauthorized" error before user sees permission dialog.

#### Solution
```dart
Future<bool> isAvailable() async {
  if (Platform.isIOS) {
    return true;  // Let flutter_blue_plus prompt for permission
  }

  // Only check on Android
  final adapterState = await FlutterBluePlus.adapterState.first;
  return adapterState == BluetoothAdapterState.on;
}
```

---

## BLE Protocol Details

### Service and Characteristic UUIDs

```dart
static const String serviceUuid = '0000FE01-0000-1000-8000-00805F9B34FB';
static const String metadataCharUuid = '0000FE02-0000-1000-8000-00805F9B34FB';
static const String dataChunkCharUuid = '0000FE03-0000-1000-8000-00805F9B34FB';
static const String controlCharUuid = '0000FE04-0000-1000-8000-00805F9B34FB';
```

### Data Chunking Strategy

**Maximum Transmission Unit (MTU)**:
- iOS: typically 185 bytes
- Android: up to 517 bytes
- **Conservative max**: 512 bytes

**Chunk Size Calculation**:
```dart
static const int maxMtu = 512;
static const int maxChunkDataSize = maxMtu - 3 - 4;  // 505 bytes
// 3 bytes: ATT overhead
// 4 bytes: chunk header (index + total)
```

### Metadata Encoding

```
Format: [version:1][nameLen:1][name:N][senderLen:1][sender:N][totalBytes:4][totalChunks:4]

Example:
01           - Protocol version 1
09           - Device name length (9)
69506820316239  - "iPhone 12" in UTF-8
0A           - Sender name length (10)
4472...      - "Dr. Smith" in UTF-8
00001234     - Total bytes (4660)
00000009     - Total chunks (9)
```

### Transfer Flow Sequence

1. **Sender (Peripheral)**:
   ```
   Start advertising with sender name
   → Wait for central to connect
   → Central reads metadata
   → Central subscribes to data characteristic
   → Send chunks sequentially via notifications
   → Send all chunks
   → Call onTransferComplete
   ```

2. **Receiver (Central)**:
   ```
   Scan for service UUID
   → Discover sender from advertisement
   → Connect to device
   → Read metadata characteristic
   → Subscribe to data chunk characteristic
   → Receive chunks via notifications
   → Reassemble data
   → Disconnect
   ```

---

## UI Considerations

### Transfer Completion Handling

```dart
class _BleTransferScreenState extends State<BleTransferScreen> {
  bool _isClosing = false;  // Prevent duplicate closes

  void _showSuccessAndClose() {
    if (_isClosing) {
      debugPrint('[BLE] Already closing, ignoring');
      return;
    }
    _isClosing = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }
}
```

### Progress Updates

```dart
void _updateProgress(
  TransferState state,
  String message, {
  int? bytesTransferred,
  int? totalBytes,
}) {
  _progressController.add(TransferProgress(
    method: method,
    state: state,
    statusMessage: message,
    bytesTransferred: bytesTransferred ?? 0,
    totalBytes: totalBytes ?? 0,
  ));
}
```

### Error Handling

```dart
_progressSubscription = _bleStrategy.progressStream.listen((progress) {
  if (mounted) {
    setState(() {
      _state = progress.state;
      _statusMessage = progress.statusMessage ?? '';

      if (progress.state == TransferState.error) {
        _errorMessage = progress.statusMessage ?? 'Unknown error';
      } else if (progress.state == TransferState.completed) {
        _showSuccessAndClose();
      }
    });
  }
});
```

---

## Network Availability Checking

### Problem
WiFi might be "connected" but not actually working (no internet, captive portal, etc.)

### Solution
```dart
Future<bool> _checkWiFiConnectivity() async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();

    // Check if connected to WiFi or Ethernet
    final hasWiFiConnection =
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet);

    if (!hasWiFiConnection) return false;

    // Verify connection actually works
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      // Can't reach internet, but WiFi might work for local network
      return true;
    }
  } catch (e) {
    return false;
  }
}

Future<TransferMethodRecommendation> recommendMethod() async {
  final hasWorkingWiFi = await _checkWiFiConnectivity();

  if (hasWorkingWiFi) {
    return TransferMethodRecommendation(
      method: TransferMethod.wifi,
      reason: 'Best option for cross-platform transfers',
    );
  }

  return TransferMethodRecommendation(
    method: TransferMethod.bluetooth,
    reason: 'WiFi not available - Bluetooth works offline',
  );
}
```

---

## Testing Checklist

### iOS → Android Transfer
- [ ] Permissions granted on both devices
- [ ] Sender name displays correctly on receiver
- [ ] All data transferred completely
- [ ] UI closes properly after transfer
- [ ] No duplicate completion events

### Android → iOS Transfer
- [ ] Sender name appears in scan response
- [ ] iOS reads service data correctly
- [ ] Transfer completes successfully
- [ ] Screen closes without black screen

### Permission Scenarios
- [ ] First launch - permissions requested
- [ ] Permissions denied - clear error message
- [ ] Bluetooth disabled - appropriate error
- [ ] Location disabled (Android) - scan fails with clear message

### Network Checks
- [ ] WiFi connected and working - recommends WiFi
- [ ] WiFi connected but no internet - still recommends WiFi (local network)
- [ ] No WiFi - recommends Bluetooth
- [ ] Network state change during transfer - handled gracefully

### Edge Cases
- [ ] Transfer cancelled mid-way - clean state
- [ ] App backgrounded during transfer - resumes or fails cleanly
- [ ] Multiple rapid scan/advertise cycles - no crashes
- [ ] Very large data sets (>1MB) - chunks properly

---

## Code Structure & Key Files

### Flutter/Dart Layer

```
lib/services/
├── ble_transfer_strategy.dart       # Main BLE logic, scanning, connecting
├── ble_peripheral_channel.dart      # Method channel bridge
├── ble_protocol.dart                # UUIDs, metadata, chunking
├── ble_permission_service.dart      # Platform-specific permissions
└── transfer_manager.dart            # High-level transfer orchestration

lib/screens/
├── ble_transfer_screen.dart         # Sender UI
└── ble_receive_screen.dart          # Receiver UI

lib/widgets/
└── transfer_method_dialog.dart      # Smart Share method selection
```

### iOS Native Layer

```
ios/Runner/
└── AppDelegate.swift
    ├── BlePeripheralChannel        # Method channel handler
    └── BlePeripheralManager        # CBPeripheralManager wrapper
```

### Android Native Layer

```
android/app/src/main/kotlin/com/example/ob_signout/
├── MainActivity.kt                  # Registers BLE channel
├── BlePeripheralChannel.kt          # Method channel handler
└── BlePeripheralManager.kt          # BluetoothGattServer wrapper
```

---

## Important Method Signatures

### Flutter → Native (Sending)

```dart
Future<void> startAdvertising({
  required Uint8List metadata,      // Encoded transfer metadata
  required List<Uint8List> chunks,  // Data chunks to send
  required String senderName,       // Display name for receiver
})
```

### Native → Flutter (Callbacks)

```dart
// State changes: 'advertising', 'connected', 'subscribed', 'complete', 'stopped'
case 'onStateChanged':
  String state = call.arguments;

// Error messages
case 'onError':
  String errorMessage = call.arguments;

// Transfer completion
case 'onTransferComplete':
  // No arguments
```

---

## Performance Considerations

### BLE Transfer Speed
- **WiFi**: ~10 KB/sec
- **Bluetooth**: ~5 KB/sec
- Small data (<100KB): BLE is acceptable
- Large data (>500KB): WiFi strongly preferred

### Chunk Size Optimization
- Larger chunks = fewer round trips
- But: Must fit in MTU
- 505 bytes is safe for all devices

### Advertisement Interval
```kotlin
// Android
.setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
.setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
```

```swift
// iOS - automatically handled by CBPeripheralManager
// No configuration needed
```

---

## Common Debugging Steps

### 1. No Devices Discovered
- ✅ Check Android location permission granted
- ✅ Check Bluetooth enabled on both devices
- ✅ Verify scanning for correct service UUID
- ✅ Check iOS isn't checking state too early
- ✅ Confirm peripheral is actually advertising (check logs)

### 2. Connection Fails
- ✅ Ensure BLUETOOTH_CONNECT permission (Android 12+)
- ✅ Check device not already connected elsewhere
- ✅ Verify service UUID matches exactly
- ✅ Check timeout settings (15 seconds is good)

### 3. Transfer Hangs
- ✅ Verify subscription to data characteristic
- ✅ Check chunks are being sent (iOS/Android logs)
- ✅ Ensure no race conditions in state machine
- ✅ Check for thread safety issues

### 4. UI Issues
- ✅ Check for duplicate completion events
- ✅ Verify `mounted` checks before setState
- ✅ Ensure Navigator pop called once
- ✅ Check stream subscriptions cancelled in dispose

---

## Lessons Learned

1. **Android location permission is non-negotiable** for BLE scanning, despite the permission name suggesting otherwise

2. **Never assume permission flags work as documented** - `neverForLocation` caused silent failures

3. **Platform-specific advertising has different capabilities** - iOS can set device name directly, Android requires scan response workaround

4. **Race conditions in native code are subtle** - Required defensive flags and careful state management

5. **Method channels need singleton pattern** - Multiple instances cause event routing chaos

6. **Always use platform-specific logging** - NSLog for iOS, not print

7. **Check network connectivity before recommending** - "Connected to WiFi" doesn't mean it works

8. **Guard against duplicate events** - UI can trigger multiple times from single native event

9. **Strong references matter on iOS** - Memory management can cause mysterious failures

10. **Test early and often on both platforms** - Behavior differs significantly between iOS and Android

---

## Future Improvements

### Potential Enhancements
- [ ] Background transfer support
- [ ] Resume interrupted transfers
- [ ] Multiple simultaneous connections
- [ ] Compression for large data sets
- [ ] Transfer progress persistence
- [ ] Automatic retry on failure

### Known Limitations
- Can't display sender name in all Android notification areas
- Single connection at a time
- No transfer queue management
- No bandwidth throttling

---

## References

### Official Documentation
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- [Apple CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Android Bluetooth LE](https://developer.android.com/guide/topics/connectivity/bluetooth/ble-overview)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

### Useful Resources
- [Android BLE Permissions Guide](https://developer.android.com/guide/topics/connectivity/bluetooth/permissions)
- [iOS Background BLE](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-24
**Author**: Implementation lessons from OB SignOut app development
