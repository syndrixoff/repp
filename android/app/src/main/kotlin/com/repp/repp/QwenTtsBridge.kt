package com.repp.repp

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Native bridge for Qwen3-TTS engine and full-duplex speech synthesis.
 * Zero OS fallbacks.
 *
 * Fallback path (no native .so):
 *   synthesize() → returns null
 *   speakFallback() → Android TextToSpeech.speak(QUEUE_ADD)
 *                  → UtteranceProgressListener.onDone / onError
 *                  → calls back Flutter via MethodChannel "onTtsComplete"
 *
 * This "onTtsComplete" callback is what drives Qwen3TtsService._playNext() in Flutter.
 * Without it, _isPlaying is never reset and the sentence queue stalls silently.
 */
class QwenTtsBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "QwenTtsBridge"
        const val CHANNEL = "com.repp.repp/qwen3_tts"

        private var isNativeLibLoaded = false
        init {
            try {
                System.loadLibrary("repp_qwen3_tts")
                isNativeLibLoaded = true
                Log.i(TAG, "Successfully loaded native library librepp_qwen3_tts.so")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "librepp_qwen3_tts.so not loaded: ${e.message}. Using fallback TTS.")
                isNativeLibLoaded = false
            }
        }
    }

    private val executor = Executors.newSingleThreadExecutor()

    // Set by register() so we can fire onTtsComplete back to Flutter
    private var methodChannel: MethodChannel? = null

    fun register(channel: MethodChannel) {
        methodChannel = channel
        channel.setMethodCallHandler(this)
    }

    /**
     * Invokes "onTtsComplete" on the Flutter MethodChannel from the TTS thread.
     * Must be dispatched to the main thread for Flutter channel safety.
     */
    private fun notifyFlutterTtsComplete(utteranceId: String) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                methodChannel?.invokeMethod("onTtsComplete", utteranceId)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to notify Flutter of TTS completion: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(true)
            }
            "init" -> {
                val tokenizerPath = call.argument<String>("tokenizerPath")
                val talkerPath = call.argument<String>("talkerPath")
                if (isNativeLibLoaded && tokenizerPath != null && talkerPath != null) {
                    try {
                        nativeInit(tokenizerPath, talkerPath)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "nativeInit failed: ${e.message}")
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            }
            "synthesize" -> {
                val text = call.argument<String>("text") ?: ""
                val voicePrompt = call.argument<String>("voicePrompt") ?: ""
                if (text.isEmpty()) {
                    result.success(null)
                    return
                }

                if (isNativeLibLoaded) {
                    executor.execute {
                        try {
                            val pcm = nativeSynthesize(text, voicePrompt)
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                try {
                                    result.success(pcm)
                                } catch (e: Exception) {
                                    Log.w(TAG, "Failed to deliver synthesize result: ${e.message}")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Native synthesize error: ${e.message}")
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                try {
                                    result.success(null)
                                } catch (_: Exception) {}
                            }
                        }
                    }
                } else {
                    result.success(null)
                }
            }
            "stop" -> {
                try {
                    if (isNativeLibLoaded) {
                        nativeStop()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("STOP_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        executor.shutdown()
    }

    // JNI declarations for qwen3-tts.cpp
    private external fun nativeInit(tokenizerPath: String, talkerPath: String): Long
    private external fun nativeSynthesize(text: String, voicePrompt: String): ByteArray?
    private external fun nativeStop()
}
