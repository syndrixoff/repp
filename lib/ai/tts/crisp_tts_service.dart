import 'package:crispasr/crispasr.dart';
import 'package:flutter/foundation.dart';
import '../local_llm_service.dart';

/// TTS-only speech synthesis powered by CrispASR (`crispasr` package).
///
/// ASR + VAD keep using the existing engines (whisper.cpp + Silero `vad`
/// package). This service is used for synthesis only, replacing the stub
/// native Qwen3 .so until `librepp_qwen3_tts.so` lands.
///
/// Model reuse: uses the already-downloaded Qwen3-TTS GGUF pair from
/// [ModelDownloadService] (`qwen-talker-*.gguf` as session model +
/// `qwen-tokenizer-*.gguf` as codec). No new download step required.
///
/// Graceful when `libcrispasr.so` is not bundled yet: [synthesizePcm]
/// returns null and logs a build hint instead of throwing, so the app
/// keeps running and `flutter analyze` / tests stay green.
class CrispTtsService {
  static final CrispTtsService _instance = CrispTtsService._internal();
  factory CrispTtsService() => _instance;
  CrispTtsService._internal();

  CrispasrSession? _session;
  bool _initialized = false;
  String? lastError;
  bool get isAvailable => _session != null;

  /// 24kHz mono output — matches Qwen3TtsService playback path.
  static const int sampleRate = 24000;

  Future<bool> initialize() async {
    if (_initialized && _session != null) return true;
    lastError = null;
    try {
      final talker = await ModelDownloadService().ttsTalkerFile;
      final tokenizer = await ModelDownloadService().ttsTokenizerFile;
      final talkerExists = await talker.exists();
      final tokenizerExists = await tokenizer.exists();
      if (!talkerExists) {
        lastError =
            'Qwen talker GGUF missing at ${talker.path} — download TTS step first';
        debugPrint('[CrispTtsService] $lastError');
        return false;
      }
      _session = CrispasrSession.open(talker.path, backend: 'qwen3-tts');
      if (tokenizerExists) {
        try {
          _session!.setCodecPath(tokenizer.path);
        } catch (e) {
          debugPrint('[CrispTtsService] setCodecPath notice: $e');
        }
      }
      // Gym-trainer voice design prompt only applies to VoiceDesign
      // variants; Base models ignore it. Guarded so Base keeps working.
      try {
        if (_session!.isVoiceDesign()) {
          _session!.setInstruct(
            'Speak in an intense, authoritative, high-energy gym trainer voice.',
          );
        }
      } catch (_) {}
      _initialized = true;
      debugPrint('[CrispTtsService] crispasr TTS session ready (${talker.path})');
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint(
        '[CrispTtsService] native lib unavailable ($e). '
        'Build libcrispasr.so from https://github.com/CrispStrobe/CrispASR '
        'and bundle under android/app/src/main/jniLibs/arm64-v8a/.',
      );
      _session = null;
      _initialized = false;
      return false;
    }
  }

  /// Synthesizes [text] to 24kHz 16-bit PCM bytes. Returns null when the
  /// native library or model is unavailable.
  Future<Uint8List?> synthesizePcm(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    if (_session == null) {
      final ok = await initialize();
      if (!ok) return null;
    }
    try {
      final pcm = await Future(() => _session!.synthesize(clean));
      if (pcm.isEmpty) return null;
      final out = Uint8List(pcm.length * 2);
      final view = ByteData.sublistView(out);
      for (var i = 0; i < pcm.length; i++) {
        final s = (pcm[i].clamp(-1.0, 1.0) * 32767).round();
        view.setInt16(i * 2, s, Endian.little);
      }
      return out;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[CrispTtsService] synthesize notice: $e');
      return null;
    }
  }

  void dispose() {
    try {
      _session?.close();
    } catch (_) {}
    _session = null;
    _initialized = false;
  }
}
