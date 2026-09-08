package com.repp.repp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ttsBridge: QwenTtsBridge? = null
    private var vadBridge: SileroVadBridge? = null
    private var whisperBridge: WhisperAsrBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = QwenTtsBridge(context)
        ttsBridge = bridge
        // Use register() so the bridge holds the channel ref needed for onTtsComplete callbacks
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QwenTtsBridge.CHANNEL)
        bridge.register(channel)

        val sBridge = SileroVadBridge(context)
        vadBridge = sBridge
        val vadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SileroVadBridge.CHANNEL)
        sBridge.register(vadChannel)

        val wBridge = WhisperAsrBridge(context)
        whisperBridge = wBridge
        val whisperChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WhisperAsrBridge.CHANNEL)
        wBridge.register(whisperChannel)
    }

    override fun onDestroy() {
        ttsBridge?.release()
        vadBridge?.release()
        whisperBridge?.release()
        super.onDestroy()
    }
}
