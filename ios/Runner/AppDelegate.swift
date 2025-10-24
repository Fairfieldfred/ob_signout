import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Keep a strong reference to the BLE channel
  private var bleChannel: BlePeripheralChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register BLE peripheral channel
    NSLog("[AppDelegate] Registering BLE peripheral channel")
    let controller = window?.rootViewController as! FlutterViewController
    bleChannel = BlePeripheralChannel()
    bleChannel?.register(with: registrar(forPlugin: "BlePeripheralPlugin")!)
    NSLog("[AppDelegate] BLE peripheral channel registered")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - BLE Peripheral Channel

/// Flutter method channel for BLE peripheral operations.
class BlePeripheralChannel {
    static let channelName = "com.obsignout/ble_peripheral"

    private var peripheralManager: BlePeripheralManager?
    private var channel: FlutterMethodChannel?

    func register(with registrar: FlutterPluginRegistrar) {
        NSLog("[BLE Channel] Registering channel with name: \(BlePeripheralChannel.channelName)")
        channel = FlutterMethodChannel(name: BlePeripheralChannel.channelName, binaryMessenger: registrar.messenger())

        channel?.setMethodCallHandler { [weak self] (call, result) in
            NSLog("[BLE Channel] Method call handler invoked for: \(call.method)")
            self?.handle(call, result: result)
        }
        NSLog("[BLE Channel] Method call handler registered")
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("[BLE Channel] Received method call: \(call.method)")
        switch call.method {
        case "startAdvertising":
            handleStartAdvertising(call, result: result)

        case "stopAdvertising":
            handleStopAdvertising(result)

        default:
            NSLog("[BLE Channel] Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStartAdvertising(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("[BLE Channel] handleStartAdvertising called")
        guard let args = call.arguments as? [String: Any],
              let metadataBytes = args["metadata"] as? FlutterStandardTypedData,
              let chunksData = args["chunks"] as? [FlutterStandardTypedData],
              let senderName = args["senderName"] as? String else {
            NSLog("[BLE Channel] Invalid arguments")
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let metadata = metadataBytes.data
        let chunks = chunksData.map { $0.data }
        NSLog("[BLE Channel] Got \(chunks.count) chunks, sender: \(senderName)")

        if peripheralManager == nil {
            NSLog("[BLE Channel] Creating new BlePeripheralManager")
            peripheralManager = BlePeripheralManager()
            setupCallbacks()
        }

        NSLog("[BLE Channel] Calling startAdvertising on peripheral manager")
        peripheralManager?.startAdvertising(metadata: metadata, chunks: chunks, senderName: senderName)
        result(nil)
    }

    private func handleStopAdvertising(_ result: @escaping FlutterResult) {
        peripheralManager?.stopAdvertising()
        result(nil)
    }

    private func setupCallbacks() {
        peripheralManager?.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.channel?.invokeMethod("onStateChanged", arguments: state)
            }
        }

        peripheralManager?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.channel?.invokeMethod("onError", arguments: error)
            }
        }

        peripheralManager?.onTransferComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.channel?.invokeMethod("onTransferComplete", arguments: nil)
            }
        }
    }
}

// MARK: - BLE Peripheral Manager

/// BLE Peripheral Manager for advertising and serving patient data.
///
/// This class implements a GATT server that advertises the OB SignOut service
/// and serves patient data to central devices via chunked transfers.
class BlePeripheralManager: NSObject {
    // GATT Service and Characteristic UUIDs (must match protocol definition)
    private let serviceUUID = CBUUID(string: "0000FE01-0000-1000-8000-00805F9B34FB")
    private let metadataCharUUID = CBUUID(string: "0000FE02-0000-1000-8000-00805F9B34FB")
    private let dataChunkCharUUID = CBUUID(string: "0000FE03-0000-1000-8000-00805F9B34FB")
    private let controlCharUUID = CBUUID(string: "0000FE04-0000-1000-8000-00805F9B34FB")

    private var peripheralManager: CBPeripheralManager?
    private var service: CBMutableService?
    private var metadataCharacteristic: CBMutableCharacteristic?
    private var dataChunkCharacteristic: CBMutableCharacteristic?
    private var controlCharacteristic: CBMutableCharacteristic?

    // Data to be transferred
    private var metadataBytes: Data?
    private var chunks: [Data] = []
    private var currentChunkIndex: Int = 0
    private var senderName: String = "OB SignOut"

    // Connected centrals
    private var subscribedCentral: CBCentral?

    // State flags
    private var isSettingUpService = false

    // Callbacks
    var onStateChanged: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onTransferComplete: (() -> Void)?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Prepares data for transfer and starts advertising.
    func startAdvertising(metadata: Data, chunks: [Data], senderName: String) {
        NSLog("[BLE] startAdvertising called with \(chunks.count) chunks, sender: \(senderName)")
        self.metadataBytes = metadata
        self.chunks = chunks
        self.currentChunkIndex = 0
        self.senderName = senderName

        // Check if peripheral manager is ready
        let state = peripheralManager?.state ?? .unknown
        NSLog("[BLE] Peripheral manager state: \(state.rawValue)")

        if state == .poweredOn {
            NSLog("[BLE] State is poweredOn, calling setupService")
            // Setup service - advertising will start in didAdd service callback
            setupService()
        } else {
            NSLog("[BLE] State is NOT poweredOn, waiting for state change")
        }
        // Otherwise, setupService will be called when state becomes .poweredOn
    }

    /// Stops advertising and cleans up.
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        subscribedCentral = nil
        currentChunkIndex = 0
        onStateChanged?("stopped")
    }

    private func setupService() {
        NSLog("[BLE] setupService called")
        // Prevent duplicate service setup
        if isSettingUpService {
            NSLog("[BLE] Already setting up service, returning")
            return
        }
        isSettingUpService = true
        NSLog("[BLE] Setting isSettingUpService = true")

        // Create metadata characteristic (read-only)
        metadataCharacteristic = CBMutableCharacteristic(
            type: metadataCharUUID,
            properties: [.read],
            value: nil, // Value provided on read request
            permissions: [.readable]
        )

        // Create data chunk characteristic (read + notify)
        dataChunkCharacteristic = CBMutableCharacteristic(
            type: dataChunkCharUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        // Create control characteristic (write + notify)
        controlCharacteristic = CBMutableCharacteristic(
            type: controlCharUUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )

        // Create service with characteristics
        service = CBMutableService(type: serviceUUID, primary: true)
        service?.characteristics = [
            metadataCharacteristic!,
            dataChunkCharacteristic!,
            controlCharacteristic!
        ]

        // Add service to peripheral manager
        NSLog("[BLE] Removing all services and adding new service")
        peripheralManager?.removeAllServices()
        peripheralManager?.add(service!)
        NSLog("[BLE] Service added to peripheral manager")
    }

    private func startAdvertisingInternal() {
        NSLog("[BLE] startAdvertisingInternal called")
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: senderName
        ]

        NSLog("[BLE] Starting advertising with service UUID: \(serviceUUID), name: \(senderName)")
        peripheralManager?.startAdvertising(advertisementData)
        NSLog("[BLE] Sending advertising state to Flutter")
        onStateChanged?("advertising")
    }

    private func sendNextChunk() {
        guard let central = subscribedCentral,
              let characteristic = dataChunkCharacteristic,
              currentChunkIndex < chunks.count else {
            return
        }

        let chunkData = chunks[currentChunkIndex]
        let success = peripheralManager?.updateValue(chunkData, for: characteristic, onSubscribedCentrals: [central]) ?? false

        if success {
            currentChunkIndex += 1

            // Check if transfer is complete
            if currentChunkIndex >= chunks.count {
                onTransferComplete?()
                // Note: Don't also send onStateChanged("complete") - that would be redundant
            } else {
                // Send next chunk asynchronously to avoid stack overflow
                DispatchQueue.main.async { [weak self] in
                    self?.sendNextChunk()
                }
            }
        } else {
            // If updateValue returns false, the queue is full
            // We'll be called again in peripheralManagerIsReady(toUpdateSubscribers:)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BlePeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        NSLog("[BLE] peripheralManagerDidUpdateState: \(peripheral.state.rawValue)")
        switch peripheral.state {
        case .poweredOn:
            NSLog("[BLE] State changed to poweredOn")
            onStateChanged?("powered_on")
            // If we have data ready, setup the service
            // Advertising will start automatically in didAdd service callback
            if metadataBytes != nil {
                NSLog("[BLE] metadataBytes is set, calling setupService from state change")
                setupService()
            } else {
                NSLog("[BLE] metadataBytes is nil, not calling setupService")
            }

        case .poweredOff:
            NSLog("[BLE] State changed to poweredOff")
            onStateChanged?("powered_off")
            onError?("Bluetooth is turned off. Please enable Bluetooth.")

        case .unauthorized:
            NSLog("[BLE] State changed to unauthorized")
            onStateChanged?("unauthorized")
            onError?("Bluetooth permission denied. Please enable in Settings.")

        case .unsupported:
            NSLog("[BLE] State changed to unsupported")
            onStateChanged?("unsupported")
            onError?("Bluetooth LE is not supported on this device.")

        default:
            NSLog("[BLE] State changed to: \(peripheral.state.rawValue)")
            onStateChanged?("unknown")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        NSLog("[BLE] didAdd service callback")
        isSettingUpService = false

        if let error = error {
            NSLog("[BLE] Error adding service: \(error.localizedDescription)")
            onError?("Failed to add service: \(error.localizedDescription)")
            return
        }

        NSLog("[BLE] Service added successfully")
        // Service added successfully, now we can start advertising
        if metadataBytes != nil {
            NSLog("[BLE] Calling startAdvertisingInternal")
            startAdvertisingInternal()
        } else {
            NSLog("[BLE] metadataBytes is nil, not starting advertising")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        NSLog("[BLE] peripheralManagerDidStartAdvertising callback")
        if let error = error {
            NSLog("[BLE] Error starting advertising: \(error.localizedDescription)")
            onError?("Failed to start advertising: \(error.localizedDescription)")
            return
        }
        NSLog("[BLE] Advertising started successfully")
        onStateChanged?("advertising")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // Handle metadata read request
        if request.characteristic.uuid == metadataCharUUID {
            if let metadata = metadataBytes {
                if request.offset > metadata.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }

                let range = request.offset..<min(metadata.count, request.offset + request.central.maximumUpdateValueLength)
                request.value = metadata.subdata(in: range)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
        }
        // Handle data chunk read request
        else if request.characteristic.uuid == dataChunkCharUUID {
            if currentChunkIndex < chunks.count {
                let chunkData = chunks[currentChunkIndex]
                if request.offset > chunkData.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }

                let range = request.offset..<min(chunkData.count, request.offset + request.central.maximumUpdateValueLength)
                request.value = chunkData.subdata(in: range)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
        }
        else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == controlCharUUID {
                // Handle control commands (START, ACK, etc.)
                if let value = request.value, !value.isEmpty {
                    let command = value[0]

                    switch command {
                    case 0x01: // START
                        currentChunkIndex = 0
                        peripheral.respond(to: request, withResult: .success)
                        // Start sending chunks
                        sendNextChunk()

                    case 0x02: // ACK
                        peripheral.respond(to: request, withResult: .success)
                        // Send next chunk
                        sendNextChunk()

                    case 0x05: // CANCEL
                        peripheral.respond(to: request, withResult: .success)
                        stopAdvertising()

                    default:
                        peripheral.respond(to: request, withResult: .success)
                    }
                } else {
                    peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                }
            } else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if characteristic.uuid == dataChunkCharUUID {
            subscribedCentral = central
            currentChunkIndex = 0
            onStateChanged?("subscribed")

            // Start sending chunks when client subscribes
            sendNextChunk()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == dataChunkCharUUID {
            if subscribedCentral?.identifier == central.identifier {
                subscribedCentral = nil
                onStateChanged?("unsubscribed")
            }
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Called when the BLE queue is ready to send more data
        // Continue sending the next chunk
        sendNextChunk()
    }
}
