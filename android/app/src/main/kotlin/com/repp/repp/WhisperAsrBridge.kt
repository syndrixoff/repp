package com.repp.repp

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native bridge for Whisper Tiny ASR (LiteRT).
 * Channel: com.repp.repp/whisper_asr
 */
class WhisperAsrBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "WhisperAsrBridge"
        const val CHANNEL = "com.repp.repp/whisper_asr"
    }

    private var isLoaded = false
    private var modelFile: File? = null

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val path = call.argument<String>("modelPath")
                if (path != null) {
                    val f = File(path)
                    if (f.exists() && f.length() > 0) {
                        modelFile = f
                        isLoaded = true
                        Log.i(TAG, "Whisper model verified at: $path (${f.length()} bytes)")
                        result.success(true)
                    } else {
                        Log.w(TAG, "Whisper model file not found at: $path")
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            }
            "transcribe" -> {
                result.success(null)
            }
            "release" -> {
                isLoaded = false
                modelFile = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        isLoaded = false
        modelFile = null
    }
}
