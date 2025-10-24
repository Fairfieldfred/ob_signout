package com.example.ob_signout

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

/**
 * Flutter method channel for BLE peripheral operations.
 */
class BlePeripheralChannel(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL_NAME = "com.obsignout/ble_peripheral"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var peripheralManager: BlePeripheralManager? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    handleStartAdvertising(call.arguments, result)
                }
                "stopAdvertising" -> {
                    handleStopAdvertising(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleStartAdvertising(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<String, Any>

        if (args == null) {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        val metadata = args["metadata"] as? ByteArray
        val chunksData = args["chunks"] as? List<ByteArray>
        val senderName = args["senderName"] as? String

        if (metadata == null || chunksData == null || senderName == null) {
            result.error("INVALID_ARGS", "Missing metadata, chunks, or senderName", null)
            return
        }

        if (peripheralManager == null) {
            peripheralManager = BlePeripheralManager(context)
            setupCallbacks()
        }

        peripheralManager?.startAdvertising(metadata, chunksData, senderName)
        result.success(null)
    }

    private fun handleStopAdvertising(result: MethodChannel.Result) {
        peripheralManager?.stopAdvertising()
        result.success(null)
    }

    private fun setupCallbacks() {
        peripheralManager?.onStateChanged = { state ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onStateChanged", state)
            }
        }

        peripheralManager?.onError = { error ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onError", error)
            }
        }

        peripheralManager?.onTransferComplete = {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                channel.invokeMethod("onTransferComplete", null)
            }
        }
    }
}
