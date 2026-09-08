import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';
import '../local_llm_service.dart';
import 'speech_normalizer_service.dart';

/// Automatic Speech Recognition (ASR) service powered by whisper.cpp via whisper_cpp_flutter_plus.
/// ZERO OS fallbacks.
class WhisperAsrService {
  static final WhisperAsrService _instance = WhisperAsrService._internal();
  factory WhisperAsrService() => _instance;
  WhisperAsrService._internal();

  final SpeechNormalizerService _normalizer = SpeechNormalizerService();
  WhisperEngine? _engine;

  bool _initialized = false;
  bool get isLoaded => _engine != null;

  bool _isRecognizing = false;
  bool get isRecognizing => _isRecognizing;

  Future<void> initialize() async {
    if (_initialized && _engine != null) return;
    _initialized = true;

    try {
      final asrFile = await ModelDownloadService().asrFile;
      if (await asrFile.exists()) {
        _engine = await WhisperEngine.load(
          asrFile.path,
          config: const WhisperConfig(useGpu: true),
        );
        debugPrint('[WhisperAsrService] whisper.cpp engine loaded from ${asrFile.path}');
      } else {
        debugPrint('[WhisperAsrService] Whisper model file not found at ${asrFile.path}');
      }
    } catch (e) {
      debugPrint('[WhisperAsrService] whisper.cpp engine load notice: $e');
      _engine = null;
    }
  }

  /// Transcribes floating-point audio samples [-1.0, 1.0] at 16kHz
  Future<String> transcribeSamples(List<double> samples) async {
    if (samples.isEmpty) return '';
    final floatSamples = Float32List.fromList(samples);
    return transcribeFloat32(floatSamples);
  }

  /// Transcribes raw 16kHz 16-bit PCM bytes
  Future<String> transcribePcm(Uint8List pcmBytes) async {
    if (pcmBytes.isEmpty) return '';

    final sampleCount = pcmBytes.length ~/ 2;
    final floatSamples = Float32List(sampleCount);
    final byteData = ByteData.sublistView(pcmBytes);
    for (int i = 0; i < sampleCount; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      floatSamples[i] = (s / 32768.0).clamp(-1.0, 1.0);
    }

    return transcribeFloat32(floatSamples);
  }

  /// Transcribes Float32 16kHz mono audio via whisper.cpp
  Future<String> transcribeFloat32(Float32List floatSamples) async {
    if (floatSamples.isEmpty) return '';

    if (_engine == null) {
      await initialize();
    }

    if (_engine == null) {
      debugPrint('[WhisperAsrService] whisper.cpp engine not loaded. Returning empty transcript.');
      return '';
    }

    _isRecognizing = true;
    String rawText = '';

    try {
      final task = _engine!.transcribe(
        floatSamples,
        options: const TranscribeOptions(
          language: 'en',
          noTimestamps: true,
          threads: 4,
        ),
      );
      final result = await task.result;
      rawText = result.text.trim();
    } catch (e) {
      debugPrint('[WhisperAsrService] Transcription error: $e');
    } finally {
      _isRecognizing = false;
    }

    final normalized = _normalizer.normalize(rawText);
    debugPrint('[WhisperAsrService] Transcribed: "$rawText" -> Normalized: "$normalized"');
    return normalized;
  }

  void dispose() {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}
