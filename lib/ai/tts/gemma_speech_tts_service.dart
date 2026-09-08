import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// TTS-only speech synthesis via the shared flutter_gemma engine
/// (Inflect-Nano-v2 LiteRT bundle — the demonstrated end-to-end path:
/// VITS text-encoder + decoder straight to 24 kHz PCM, fixed voice).
///
/// ASR keeps its existing engine (moonshine STT via the same flutter_gemma
/// engine, Silero `vad` package for endpointing). This service is synthesis
/// only. Zero OS fallbacks: no Android TextToSpeech anywhere.
///
/// Bundle: `sasha-denisov/inflect-nano-v2-litert` (2 tflites + Matcha G2P
/// side-cars, ~34MB). Installed once via [FlutterGemma.installTts]
/// (idempotent — skipped when already installed) and synthesized through a
/// background isolate, so the UI isolate stays free.
class GemmaSpeechTtsService {
  static final GemmaSpeechTtsService _instance =
      GemmaSpeechTtsService._internal();
  factory GemmaSpeechTtsService() => _instance;
  GemmaSpeechTtsService._internal();

  static const String bundleBaseUrl =
      'https://huggingface.co/sasha-denisov/inflect-nano-v2-litert/resolve/main/';

  SpeechSynthesizer? _synth;
  bool _installAttempted = false;

  /// Test hook: when false, never touches the network — returns null unless
  /// a synthesizer is already active. Keeps unit tests hermetic.
  static bool autoInstall = true;

  String? lastError;
  bool get isAvailable => _synth != null;

  /// 24kHz mono output — matches CoachTtsService playback path.
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
      debugPrint('[GemmaSpeechTtsService] Installing Inflect-Nano-v2 bundle (~34MB first run)...');
      await FlutterGemma.installTts()
          .fromNetwork(bundleBaseUrl)
          .ofType(TtsModelType.inflect)
          .install();
      _synth = await FlutterGemma.getActiveTts();
      debugPrint('[GemmaSpeechTtsService] Inflect TTS ready via flutter_gemma engine.');
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
