import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter method channel for communicating with native BLE peripheral code.
///
/// This channel bridges Dart code with platform-specific BLE peripheral
/// implementations (iOS CBPeripheralManager, Android BluetoothGattServer).
class BlePeripheralChannel {
  static const MethodChannel _channel =
      MethodChannel('com.obsignout/ble_peripheral');

  static final BlePeripheralChannel _instance = BlePeripheralChannel._internal();

  factory BlePeripheralChannel() => _instance;

  BlePeripheralChannel._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Callbacks from native code
  final _stateController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _transferCompleteController = StreamController<void>.broadcast();

  /// Stream of state changes from the native peripheral manager.
  Stream<String> get stateStream => _stateController.stream;

  /// Stream of errors from the native peripheral manager.
  Stream<String> get errorStream => _errorController.stream;

  /// Stream indicating when a transfer is complete.
  Stream<void> get transferCompleteStream => _transferCompleteController.stream;

  /// Starts advertising with the given metadata and data chunks.
  ///
  /// [metadata] Encoded metadata about the transfer
  /// [chunks] List of data chunks to be transferred
  /// [senderName] Name of the person sending the data (displayed during scanning)
  Future<void> startAdvertising({
    required Uint8List metadata,
    required List<Uint8List> chunks,
    required String senderName,
  }) async {
    debugPrint('[BLE Channel] ====== PREPARING TO SEND ======');
    debugPrint('[BLE Channel] Total chunks to send: ${chunks.length}');
    debugPrint('[BLE Channel] Metadata length: ${metadata.length} bytes');
    debugPrint('[BLE Channel] Sender name: $senderName');

    // Log individual chunk sizes
    int totalChunkBytes = 0;
    for (int i = 0; i < chunks.length; i++) {
      final chunkSize = chunks[i].length;
      totalChunkBytes += chunkSize;
      debugPrint('[BLE Channel] Chunk $i: $chunkSize bytes');
    }

    debugPrint('[BLE Channel] Total data in chunks: $totalChunkBytes bytes');
    debugPrint('[BLE Channel] Average chunk size: ${(totalChunkBytes / chunks.length).toStringAsFixed(1)} bytes');
    debugPrint('[BLE Channel] About to invoke platform method...');
    debugPrint('[BLE Channel] ==============================');

    try {
      final result = await _channel.invokeMethod('startAdvertising', {
        'metadata': metadata,
        'chunks': chunks,
        'senderName': senderName,
      });
      debugPrint('[BLE Channel] startAdvertising method call completed, result: $result');
    } on PlatformException catch (e) {
      debugPrint('[BLE Channel] PlatformException: ${e.code} - ${e.message}');
      throw Exception('Failed to start advertising: ${e.message}');
    } catch (e) {
      debugPrint('[BLE Channel] Unexpected error: $e');
      rethrow;
    }
  }

  /// Stops advertising and cleans up resources.
  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop advertising: ${e.message}');
    }
  }

  /// Handles method calls from native code.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('[BLE Channel] Received method call: ${call.method}');
    switch (call.method) {
      case 'onStateChanged':
        final state = call.arguments as String;
        debugPrint('[BLE Channel] State changed to: $state');
        debugPrint('[BLE Channel] State stream has ${_stateController.hasListener ? "listeners" : "NO listeners"}');
        _stateController.add(state);
        debugPrint('[BLE Channel] State added to stream');
        break;

      case 'onError':
        final error = call.arguments as String;
        debugPrint('[BLE Channel] Error received: $error');
        debugPrint('[BLE Channel] Error stream has ${_errorController.hasListener ? "listeners" : "NO listeners"}');
        _errorController.add(error);
        debugPrint('[BLE Channel] Error added to stream');
        break;

      case 'onTransferComplete':
        debugPrint('[BLE Channel] Transfer complete');
        debugPrint('[BLE Channel] Transfer complete stream has ${_transferCompleteController.hasListener ? "listeners" : "NO listeners"}');
        _transferCompleteController.add(null);
        debugPrint('[BLE Channel] Transfer complete added to stream');
        break;

      default:
        debugPrint('[BLE Channel] Unknown method: ${call.method}');
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  /// Closes all stream controllers.
  void dispose() {
    _stateController.close();
    _errorController.close();
    _transferCompleteController.close();
  }
}
