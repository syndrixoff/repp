package com.repp.repp

import io.flutter.embedding.android.FlutterActivity

/// All speech AI (Gemma LLM, moonshine STT, Qwen3-TTS, Silero VAD) runs
/// through Flutter plugins over Dart FFI — zero custom native bridges,
/// zero OS speech fallbacks.
class MainActivity : FlutterActivity()
