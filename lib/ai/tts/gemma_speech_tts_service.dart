import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// TTS-only speech synthesis via the shared flutter_gemma engine
/// (Qwen3-TTS 0.6B LiteRT bundle, accelerated + iOS-capable).
///
/// ASR + VAD keep their existing engines (moonshine STT via the same
/// flutter_gemma engine, Silero `vad` package). This service is synthesis
/// only. Zero OS fallbacks: no Android TextToSpeech anywhere.
///
/// Bundle: `litert-community/Qwen3-TTS-12Hz-0.6B-Base` (talker_int4 +
/// mtp_fp32 + codec_decoder_fp32 + tokenizer + tables + demo voice).
/// Installed once via [FlutterGemma.installTts] (idempotent — skipped when
/// already installed) and synthesized through a background isolate, so the
/// UI isolate stays free.
class GemmaSpeechTtsService {
  static final GemmaSpeechTtsService _instance =
      GemmaSpeechTtsService._internal();
  factory GemmaSpeechTtsService() => _instance;
  GemmaSpeechTtsService._internal();

  static const String bundleBaseUrl =
      'https://huggingface.co/litert-community/Qwen3-TTS-12Hz-0.6B-Base/resolve/main/';

  SpeechSynthesizer? _synth;
  bool _installAttempted = false;

  /// Test hook: when false, never touches the network — returns null unless
  /// a synthesizer is already active. Keeps unit tests hermetic.
  static bool autoInstall = true;

  String? lastError;
  bool get isAvailable => _synth != null;

  /// 24kHz mono output — matches Qwen3TtsService playback path.
  static const int sampleRate = 24000;

  Future<bool> initialize() async {
    if (_synth != null) return true;
    lastError = null;
    try {
      if (FlutterGemma.hasActiveTts()) {
        _synth = await FlutterGemma.getActiveTts();
        return true;
      }
      if (!autoInstall) return false;
      if (_installAttempted) return false;
      _installAttempted = true;
      debugPrint('[GemmaSpeechTtsService] Installing Qwen3-TTS bundle (~1.9GB first run)...');
      await FlutterGemma.installTts()
          .fromNetwork(bundleBaseUrl)
          .ofType(TtsModelType.qwen3)
          .install();
      _synth = await FlutterGemma.getActiveTts();
      debugPrint('[GemmaSpeechTtsService] Qwen3-TTS ready via flutter_gemma engine.');
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[GemmaSpeechTtsService] unavailable: $e');
      _synth = null;
      return false;
    }
  }

  /// Synthesizes [text] to 24kHz 16-bit PCM bytes. Returns null when the
  /// bundle is not installed (and auto-install is off/failed).
  Future<Uint8List?> synthesizePcm(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    if (_synth == null) {
      final ok = await initialize();
      if (!ok) return null;
    }
    try {
      final pcm = await _synth!.synthesize(clean);
      if (pcm.isEmpty) return null;
      return pcm;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[GemmaSpeechTtsService] synthesize notice: $e');
      return null;
    }
  }

  void dispose() {
    try {
      _synth?.close();
    } catch (_) {}
    _synth = null;
    _installAttempted = false;
  }
}
