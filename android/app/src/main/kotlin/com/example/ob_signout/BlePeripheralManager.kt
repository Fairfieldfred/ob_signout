package com.example.ob_signout

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.*

/**
 * BLE Peripheral Manager for advertising and serving patient data.
 *
 * This class implements a GATT server that advertises the OB SignOut service
 * and serves patient data to central devices via chunked transfers.
 */
class BlePeripheralManager(private val context: Context) {
    companion object {
        private const val TAG = "BlePeripheralManager"

        // GATT Service and Characteristic UUIDs (must match protocol definition)
        val SERVICE_UUID: UUID = UUID.fromString("0000FE01-0000-1000-8000-00805F9B34FB")
        val METADATA_CHAR_UUID: UUID = UUID.fromString("0000FE02-0000-1000-8000-00805F9B34FB")
        val DATA_CHUNK_CHAR_UUID: UUID = UUID.fromString("0000FE03-0000-1000-8000-00805F9B34FB")
        val CONTROL_CHAR_UUID: UUID = UUID.fromString("0000FE04-0000-1000-8000-00805F9B34FB")

        // Control commands
        const val CMD_START: Byte = 0x01
        const val CMD_ACK: Byte = 0x02
        const val CMD_RETRY: Byte = 0x03
        const val CMD_COMPLETE: Byte = 0x04
        const val CMD_CANCEL: Byte = 0x05
    }

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    // Data to be transferred
    private var metadataBytes: ByteArray? = null
    private var chunks: List<ByteArray> = listOf()
    private var currentChunkIndex: Int = 0

    // Connected device
    private var connectedDevice: BluetoothDevice? = null

    // Callbacks
    var onStateChanged: ((String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onTransferComplete: (() -> Unit)? = null

    init {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
    }

    /**
     * Prepares data for transfer and starts advertising.
     */
    fun startAdvertising(metadata: ByteArray, chunks: List<ByteArray>) {
        this.metadataBytes = metadata
        this.chunks = chunks
        this.currentChunkIndex = 0

        if (!isBluetoothEnabled()) {
            onError?.invoke("Bluetooth is turned off. Please enable Bluetooth.")
            return
        }

        if (bluetoothLeAdvertiser == null) {
            onError?.invoke("BLE advertising not supported on this device.")
            return
        }

        setupGattServer()
        startAdvertisingInternal()
    }

    /**
     * Stops advertising and cleans up.
     */
    fun stopAdvertising() {
        try {
            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            gattServer?.close()
            gattServer = null
            connectedDevice = null
            currentChunkIndex = 0
            onStateChanged?.invoke("stopped")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception stopping advertising", e)
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    private fun setupGattServer() {
        try {
            // Create GATT service
            val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

            // Metadata characteristic (read-only)
            val metadataChar = BluetoothGattCharacteristic(
                METADATA_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_READ
            )
            service.addCharacteristic(metadataChar)

            // Data chunk characteristic (read + notify)
            val dataChunkChar = BluetoothGattCharacteristic(
                DATA_CHUNK_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ
            )
            // Add Client Characteristic Configuration Descriptor for notifications
            val cccd = BluetoothGattDescriptor(
                UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
            )
            dataChunkChar.addDescriptor(cccd)
            service.addCharacteristic(dataChunkChar)

            // Control characteristic (write + notify)
            val controlChar = BluetoothGattCharacteristic(
                CONTROL_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            service.addCharacteristic(controlChar)

            // Open GATT server
            gattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
            gattServer?.addService(service)

            onStateChanged?.invoke("gatt_server_ready")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception setting up GATT server", e)
            onError?.invoke("Permission denied. Please grant Bluetooth permissions.")
        }
    }

    private fun startAdvertisingInternal() {
        try {
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setConnectable(true)
                .setTimeout(0)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()

            bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting advertising", e)
            onError?.invoke("Permission denied. Please grant Bluetooth permissions.")
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d(TAG, "Advertising started successfully")
            onStateChanged?.invoke("advertising")
        }

        override fun onStartFailure(errorCode: Int) {
            val error = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "Advertise data too large"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                ADVERTISE_FAILED_ALREADY_STARTED -> "Already advertising"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature not supported"
                else -> "Unknown error: $errorCode"
            }
            Log.e(TAG, "Advertising failed: $error")
            onError?.invoke("Failed to start advertising: $error")
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            try {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.d(TAG, "Device connected: ${device?.address}")
                        connectedDevice = device
                        onStateChanged?.invoke("connected")
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.d(TAG, "Device disconnected: ${device?.address}")
                        if (connectedDevice?.address == device?.address) {
                            connectedDevice = null
                        }
                        onStateChanged?.invoke("disconnected")
                    }
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception in connection state change", e)
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            try {
                when (characteristic?.uuid) {
                    METADATA_CHAR_UUID -> {
                        val metadata = metadataBytes ?: byteArrayOf()
                        if (offset > metadata.size) {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
                            return
                        }
                        val response = metadata.copyOfRange(offset, metadata.size)
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, response)
                    }

                    DATA_CHUNK_CHAR_UUID -> {
                        if (currentChunkIndex < chunks.size) {
                            val chunk = chunks[currentChunkIndex]
                            if (offset > chunk.size) {
                                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
                                return
                            }
                            val response = chunk.copyOfRange(offset, chunk.size)
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, response)
                        } else {
                            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                        }
                    }

                    else -> {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null)
                    }
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception in characteristic read", e)
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            try {
                if (characteristic?.uuid == CONTROL_CHAR_UUID && value != null && value.isNotEmpty()) {
                    val command = value[0]

                    when (command) {
                        CMD_START -> {
                            currentChunkIndex = 0
                            if (responseNeeded) {
                                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                            }
                            sendNextChunk(device)
                        }

                        CMD_ACK -> {
                            if (responseNeeded) {
                                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                            }
                            sendNextChunk(device)
                        }

                        CMD_CANCEL -> {
                            if (responseNeeded) {
                                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                            }
                            stopAdvertising()
                        }

                        else -> {
                            if (responseNeeded) {
                                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                            }
                        }
                    }
                } else if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, 0, null)
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception in characteristic write", e)
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            descriptor: BluetoothGattDescriptor?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            try {
                Log.d(TAG, "Descriptor write request: ${descriptor?.uuid}, char: ${descriptor?.characteristic?.uuid}")

                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }

                // Check if this is a notification subscription for the data chunk characteristic
                if (descriptor?.characteristic?.uuid == DATA_CHUNK_CHAR_UUID) {
                    // Check if notifications are being enabled
                    val enabled = value?.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) ?: false
                    Log.d(TAG, "Data chunk characteristic descriptor write - enabled: $enabled")

                    if (enabled) {
                        Log.d(TAG, "Client subscribed to notifications, starting chunk transfer")
                        connectedDevice = device
                        currentChunkIndex = 0
                        onStateChanged?.invoke("subscribed")

                        // Start sending chunks
                        sendNextChunk(device)
                    }
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception in descriptor write", e)
            } catch (e: Exception) {
                Log.e(TAG, "Exception in descriptor write", e)
            }
        }
    }

    private fun sendNextChunk(device: BluetoothDevice?) {
        try {
            if (currentChunkIndex >= chunks.size) {
                Log.d(TAG, "All chunks sent")
                onTransferComplete?.invoke()
                onStateChanged?.invoke("complete")
                return
            }

            val chunk = chunks[currentChunkIndex]
            val characteristic = gattServer?.getService(SERVICE_UUID)?.getCharacteristic(DATA_CHUNK_CHAR_UUID)
            characteristic?.value = chunk

            Log.d(TAG, "Sending chunk ${currentChunkIndex + 1}/${chunks.size} (${chunk.size} bytes)")

            device?.let {
                val success = gattServer?.notifyCharacteristicChanged(it, characteristic, false) ?: false
                if (success) {
                    currentChunkIndex++

                    // Send next chunk asynchronously to avoid stack overflow
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        sendNextChunk(device)
                    }
                } else {
                    Log.e(TAG, "Failed to send notification for chunk $currentChunkIndex")
                    onError?.invoke("Failed to send chunk $currentChunkIndex")
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception sending chunk", e)
            onError?.invoke("Security exception: ${e.message}")
        }
    }
}
