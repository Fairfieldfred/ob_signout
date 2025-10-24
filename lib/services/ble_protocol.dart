import 'dart:convert';
import 'dart:typed_data';

/// BLE Protocol for OB SignOut data transfer.
///
/// Defines the GATT services, characteristics, and data packet structure
/// for transferring patient data over Bluetooth Low Energy.
class BleProtocol {
  /// Service UUID for OB SignOut BLE transfers.
  ///
  /// Custom UUID generated for this application.
  static const String serviceUuid = '0000FE01-0000-1000-8000-00805F9B34FB';

  /// Metadata characteristic UUID (Read).
  ///
  /// Contains transfer metadata: device name, total size, chunk count.
  static const String metadataCharUuid = '0000FE02-0000-1000-8000-00805F9B34FB';

  /// Data chunk characteristic UUID (Read/Notify).
  ///
  /// Used to transfer data chunks with sequence numbers.
  static const String dataChunkCharUuid = '0000FE03-0000-1000-8000-00805F9B34FB';

  /// Control characteristic UUID (Write/Notify).
  ///
  /// Used for transfer control commands: START, ACK, RETRY, COMPLETE, CANCEL.
  static const String controlCharUuid = '0000FE04-0000-1000-8000-00805F9B34FB';

  /// Maximum MTU (Maximum Transmission Unit) for BLE.
  ///
  /// iOS: typically 185 bytes
  /// Android: up to 517 bytes
  /// We use conservative 512 to work across platforms.
  static const int maxMtu = 512;

  /// Maximum data payload per chunk.
  ///
  /// 3 bytes for ATT overhead, 4 bytes for chunk header.
  static const int maxChunkDataSize = maxMtu - 3 - 4;

  /// Protocol version.
  static const int protocolVersion = 1;
}

/// Control commands for BLE transfer.
enum BleControlCommand {
  start(0x01),
  ack(0x02),
  retry(0x03),
  complete(0x04),
  cancel(0x05),
  error(0xFF);

  const BleControlCommand(this.value);
  final int value;

  static BleControlCommand? fromValue(int value) {
    for (final cmd in BleControlCommand.values) {
      if (cmd.value == value) return cmd;
    }
    return null;
  }
}

/// Metadata for a BLE transfer.
class BleTransferMetadata {
  final String deviceName;
  final int totalBytes;
  final int totalChunks;
  final String senderName;

  const BleTransferMetadata({
    required this.deviceName,
    required this.totalBytes,
    required this.totalChunks,
    required this.senderName,
  });

  /// Creates metadata from JSON data.
  factory BleTransferMetadata.fromJsonData(String deviceName, String senderName, String jsonData) {
    final bytes = utf8.encode(jsonData);
    final totalChunks = (bytes.length / BleProtocol.maxChunkDataSize).ceil();

    return BleTransferMetadata(
      deviceName: deviceName,
      totalBytes: bytes.length,
      totalChunks: totalChunks,
      senderName: senderName,
    );
  }

  /// Encodes metadata to bytes.
  ///
  /// Format: [version][nameLength][name][senderLength][sender][totalBytes][totalChunks]
  Uint8List toBytes() {
    final nameBytes = utf8.encode(deviceName);
    final senderBytes = utf8.encode(senderName);

    final buffer = ByteData(1 + 1 + nameBytes.length + 1 + senderBytes.length + 4 + 4);
    int offset = 0;

    // Version
    buffer.setUint8(offset++, BleProtocol.protocolVersion);

    // Device name
    buffer.setUint8(offset++, nameBytes.length);
    for (final byte in nameBytes) {
      buffer.setUint8(offset++, byte);
    }

    // Sender name
    buffer.setUint8(offset++, senderBytes.length);
    for (final byte in senderBytes) {
      buffer.setUint8(offset++, byte);
    }

    // Total bytes (4 bytes)
    buffer.setUint32(offset, totalBytes, Endian.big);
    offset += 4;

    // Total chunks (4 bytes)
    buffer.setUint32(offset, totalChunks, Endian.big);

    return buffer.buffer.asUint8List();
  }

  /// Decodes metadata from bytes.
  factory BleTransferMetadata.fromBytes(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);
    int offset = 0;

    // Version
    final version = buffer.getUint8(offset++);
    if (version != BleProtocol.protocolVersion) {
      throw Exception('Unsupported protocol version: $version');
    }

    // Device name
    final nameLength = buffer.getUint8(offset++);
    final nameBytes = bytes.sublist(offset, offset + nameLength);
    final deviceName = utf8.decode(nameBytes);
    offset += nameLength;

    // Sender name
    final senderLength = buffer.getUint8(offset++);
    final senderBytes = bytes.sublist(offset, offset + senderLength);
    final senderName = utf8.decode(senderBytes);
    offset += senderLength;

    // Total bytes
    final totalBytes = buffer.getUint32(offset, Endian.big);
    offset += 4;

    // Total chunks
    final totalChunks = buffer.getUint32(offset, Endian.big);

    return BleTransferMetadata(
      deviceName: deviceName,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      senderName: senderName,
    );
  }
}

/// A single chunk of data in a BLE transfer.
class BleDataChunk {
  final int chunkIndex;
  final int totalChunks;
  final Uint8List data;

  const BleDataChunk({
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
  });

  /// Encodes chunk to bytes.
  ///
  /// Format: [chunkIndex:2][totalChunks:2][data...]
  Uint8List toBytes() {
    final buffer = ByteData(4 + data.length);

    // Chunk index (2 bytes)
    buffer.setUint16(0, chunkIndex, Endian.big);

    // Total chunks (2 bytes)
    buffer.setUint16(2, totalChunks, Endian.big);

    // Data
    final result = buffer.buffer.asUint8List();
    result.setRange(4, 4 + data.length, data);

    return result;
  }

  /// Decodes chunk from bytes.
  factory BleDataChunk.fromBytes(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);

    final chunkIndex = buffer.getUint16(0, Endian.big);
    final totalChunks = buffer.getUint16(2, Endian.big);
    final data = bytes.sublist(4);

    return BleDataChunk(
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      data: data,
    );
  }

  /// Validates chunk integrity.
  bool isValid() {
    return chunkIndex >= 0 &&
           chunkIndex < totalChunks &&
           data.length <= BleProtocol.maxChunkDataSize;
  }
}

/// Utility class for chunking and reassembling data.
class BleDataChunker {
  /// Splits data into chunks for BLE transfer.
  static List<BleDataChunk> chunkData(String jsonData) {
    final bytes = utf8.encode(jsonData);
    final totalChunks = (bytes.length / BleProtocol.maxChunkDataSize).ceil();
    final chunks = <BleDataChunk>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * BleProtocol.maxChunkDataSize;
      final end = (start + BleProtocol.maxChunkDataSize).clamp(0, bytes.length);
      final chunkData = Uint8List.fromList(bytes.sublist(start, end));

      chunks.add(BleDataChunk(
        chunkIndex: i,
        totalChunks: totalChunks,
        data: chunkData,
      ));
    }

    return chunks;
  }

  /// Reassembles chunks back into original data.
  ///
  /// Validates that all chunks are present and in order.
  static String reassembleChunks(List<BleDataChunk> chunks) {
    if (chunks.isEmpty) {
      throw Exception('No chunks to reassemble');
    }

    // Sort by chunk index
    chunks.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    // Validate completeness
    final totalChunks = chunks.first.totalChunks;
    if (chunks.length != totalChunks) {
      throw Exception('Missing chunks: expected $totalChunks, got ${chunks.length}');
    }

    // Validate sequence
    for (int i = 0; i < chunks.length; i++) {
      if (chunks[i].chunkIndex != i) {
        throw Exception('Chunk sequence error at index $i');
      }
      if (!chunks[i].isValid()) {
        throw Exception('Invalid chunk at index $i');
      }
    }

    // Reassemble data
    final allBytes = <int>[];
    for (final chunk in chunks) {
      allBytes.addAll(chunk.data);
    }

    return utf8.decode(allBytes);
  }
}

/// Control message for BLE transfer.
class BleControlMessage {
  final BleControlCommand command;
  final int? chunkIndex;
  final String? errorMessage;

  const BleControlMessage({
    required this.command,
    this.chunkIndex,
    this.errorMessage,
  });

  /// Encodes control message to bytes.
  ///
  /// Format: [command:1][chunkIndex?:2][errorLength?:1][error?...]
  Uint8List toBytes() {
    if (errorMessage != null) {
      final errorBytes = utf8.encode(errorMessage!);
      final buffer = ByteData(1 + 1 + errorBytes.length);

      buffer.setUint8(0, command.value);
      buffer.setUint8(1, errorBytes.length);

      final result = buffer.buffer.asUint8List();
      result.setRange(2, 2 + errorBytes.length, errorBytes);

      return result;
    } else if (chunkIndex != null) {
      final buffer = ByteData(3);
      buffer.setUint8(0, command.value);
      buffer.setUint16(1, chunkIndex!, Endian.big);
      return buffer.buffer.asUint8List();
    } else {
      return Uint8List.fromList([command.value]);
    }
  }

  /// Decodes control message from bytes.
  factory BleControlMessage.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw Exception('Empty control message');
    }

    final command = BleControlCommand.fromValue(bytes[0]);
    if (command == null) {
      throw Exception('Unknown control command: ${bytes[0]}');
    }

    if (bytes.length >= 3 && command == BleControlCommand.ack) {
      final buffer = ByteData.sublistView(bytes);
      final chunkIndex = buffer.getUint16(1, Endian.big);
      return BleControlMessage(command: command, chunkIndex: chunkIndex);
    } else if (bytes.length > 2 && command == BleControlCommand.error) {
      final errorLength = bytes[1];
      final errorBytes = bytes.sublist(2, 2 + errorLength);
      final errorMessage = utf8.decode(errorBytes);
      return BleControlMessage(command: command, errorMessage: errorMessage);
    }

    return BleControlMessage(command: command);
  }
}
