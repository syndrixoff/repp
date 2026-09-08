import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Automatic Speech Recognition (ASR) via the shared flutter_gemma engine
/// (moonshine-tiny LiteRT, accelerated + iOS-capable).
/// ZERO OS fallbacks: no OS STT anywhere.
class WhisperAsrService {
  static final WhisperAsrService _instance = WhisperAsrService._internal();
  factory WhisperAsrService() => _instance;
  WhisperAsrService._internal();

  static const String modelUrl =
      'https://huggingface.co/litert-community/moonshine-tiny/resolve/main/moonshine_tiny_5s_f32.tflite';
  static const String tokenizerUrl =
      'https://huggingface.co/UsefulSensors/moonshine/resolve/main/ctranslate2/tiny/tokenizer.json';

  /// Moonshine fixed input window: 5 s @ 16 kHz.
  static const int windowSamples = 80000;

  SpeechRecognizer? _recognizer;
  bool _installAttempted = false;

  /// Test hook: when false, never touches the network — transcription
  /// returns empty unless a recognizer is already active.
  static bool autoInstall = true;

  String? lastError;
  String? get error => lastError;

  bool get isLoaded => _recognizer != null;

  bool _isRecognizing = false;
  bool get isRecognizing => _isRecognizing;

  Future<void> initialize() async {
    if (_recognizer != null) return;
    lastError = null;
    try {
      if (FlutterGemma.hasActiveStt()) {
        _recognizer = await FlutterGemma.getActiveStt();
        debugPrint('[WhisperAsrService] moonshine STT active via flutter_gemma engine.');
        return;
      }
      if (!autoInstall || _installAttempted) return;
      _installAttempted = true;
      debugPrint('[WhisperAsrService] Installing moonshine-tiny STT bundle (~110MB first run)...');
      await FlutterGemma.installStt()
          .modelFromNetwork(modelUrl)
          .tokenizerFromNetwork(tokenizerUrl)
          .ofType(SttModelType.moonshine)
          .install();
      _recognizer = await FlutterGemma.getActiveStt();
      debugPrint('[WhisperAsrService] moonshine STT ready via flutter_gemma engine.');
    } catch (e) {
      lastError = e.toString();
      debugPrint('[WhisperAsrService] STT unavailable: $e');
      _recognizer = null;
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

  /// Transcribes Float32 16kHz mono audio. Longer utterances are split into
  /// non-overlapping 5 s moonshine windows and joined.
  Future<String> transcribeFloat32(Float32List floatSamples) async {
    if (floatSamples.isEmpty) return '';
    if (_isRecognizing) {
      debugPrint('[WhisperAsrService] Already recognizing — dropping overlapping request.');
      return '';
    }

    if (_recognizer == null) {
      await initialize();
    }

    if (_recognizer == null) {
      debugPrint('[WhisperAsrService] STT engine not loaded (${lastError ?? 'unknown'}). Returning empty transcript.');
      return '';
    }

    _isRecognizing = true;
    try {
      final parts = <String>[];
      for (var start = 0; start < floatSamples.length; start += windowSamples) {
        final end = (start + windowSamples).clamp(0, floatSamples.length);
        final window = floatSamples.sublist(start, end);
        if (window.isEmpty) break;
        final pcm = Uint8List(window.length * 2);
        final view = ByteData.sublistView(pcm);
        for (var i = 0; i < window.length; i++) {
          view.setInt16(i * 2, (window[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
        }
        final text = (await _recognizer!.transcribe(pcm)).trim();
        if (text.isNotEmpty) parts.add(text);
        if (end >= floatSamples.length) break;
      }
      final rawText = parts.join(' ').trim();
      // Raw transcript — thinking cleanup is S1's job, not regex.
      debugPrint('[WhisperAsrService] Transcribed: "$rawText"');
      return rawText;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[WhisperAsrService] Transcription error: $e');
      return '';
    } finally {
      _isRecognizing = false;
    }
  }

  void dispose() {
    try {
      _recognizer?.close();
    } catch (_) {}
    _recognizer = null;
    _installAttempted = false;
  }
}
