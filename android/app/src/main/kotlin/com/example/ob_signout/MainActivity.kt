package com.example.ob_signout

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register BLE peripheral channel
        BlePeripheralChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
