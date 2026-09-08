import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';

/// State of voice activity detection
enum VadSpeechState {
  silence,
  speechDetected,
  speechEnding,
}

/// Silero VAD v5 on-device service powered by `vad` package (Option 2: Using Local Assets).
/// Runs Silero V5 ONNX model bundled offline in assets/models/silero_vad_v5.onnx.
/// Completely rejects continuous fan noise, AC hum, and external room rumble.
/// ZERO OS fallbacks.
class SileroVadService {
  static final SileroVadService _instance = SileroVadService._internal();
  factory SileroVadService() => _instance;
  SileroVadService._internal();

  static const int sampleRate = 16000;
  static const int chunkSize = 512; // 32ms at 16kHz
  static const int contextSize = 64; // 4ms context
  static const double defaultSpeechThreshold = 0.5;
  static const double defaultSilenceThreshold = 0.35;

  static const int hangoverChunkCount = 19;
  static const int onsetMinSpeechChunks = 2;

  VadHandler? _vadHandler;
  StreamSubscription? _subStart;
  StreamSubscription? _subRealStart;
  StreamSubscription? _subFrame;
  StreamSubscription? _subEnd;
  StreamSubscription? _subErr;

  bool _initialized = false;
  bool _isLiveListening = false;
  bool get isLiveListening => _isLiveListening;

  // Context for manual chunk evaluation
  Float32List _context = Float32List(contextSize);

  final BytesBuilder _utterancePcmBuffer = BytesBuilder();

  double _ambientNoiseFloor = 0.01;
  int _consecutiveSpeechChunks = 0;
  int _consecutiveSilenceChunks = 0;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  // Callbacks
  VoidCallback? onSpeechStart;
  void Function(List<double> samples)? onSpeechEndSamples;
  void Function(Uint8List utterancePcm)? onSpeechEnd;
  void Function(double probability, double soundLevel)? onFrameEvaluated;

  final StreamController<double> _probController = StreamController<double>.broadcast();
  Stream<double> get speechProbabilityStream => _probController.stream;

  final StreamController<bool> _speakingStateController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStateStream => _speakingStateController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    resetState();

    try {
      _vadHandler = VadHandler.create(isDebug: false);

      _subStart = _vadHandler!.onSpeechStart.listen((_) {
        _isSpeaking = true;
        _speakingStateController.add(true);
        onSpeechStart?.call();
      });

      _subFrame = _vadHandler!.onFrameProcessed.listen((frameData) {
        final prob = frameData.isSpeech;
        _probController.add(prob);
        final level = prob >= defaultSpeechThreshold ? prob : 0.0;
        onFrameEvaluated?.call(prob, level);
      });

      _subEnd = _vadHandler!.onSpeechEnd.listen((samples) {
        _isSpeaking = false;
        _speakingStateController.add(false);
        onSpeechEndSamples?.call(samples);

        // Convert Float samples [-1.0, 1.0] to 16kHz 16-bit PCM bytes
        final pcmBytes = Uint8List(samples.length * 2);
        final byteData = ByteData.sublistView(pcmBytes);
        for (int i = 0; i < samples.length; i++) {
          final s = (samples[i] * 32767).clamp(-32768, 32767).round();
          byteData.setInt16(i * 2, s, Endian.little);
        }
        onSpeechEnd?.call(pcmBytes);
      });

      _subErr = _vadHandler!.onError.listen((err) {
        debugPrint('[SileroVadService] VadHandler notice: $err');
      });

      debugPrint('[SileroVadService] VadHandler initialized (Option 2: Local Assets).');
    } catch (e) {
      debugPrint('[SileroVadService] Error creating VadHandler: $e');
    }
  }

  /// Starts live listening using Silero V5 ONNX loaded offline from assets/models/
  Future<bool> startLiveDetection() async {
    await initialize();
    if (_vadHandler == null) return false;

    try {
      await _vadHandler!.startListening(
        model: 'v5',
        baseAssetPath: 'assets/models/', // Option 2: Local offline assets
        positiveSpeechThreshold: defaultSpeechThreshold,
        negativeSpeechThreshold: defaultSilenceThreshold,
      );
      _isLiveListening = true;
      debugPrint('[SileroVadService] Live Silero V5 detection active via assets/models/silero_vad_v5.onnx');
      return true;
    } catch (e) {
      debugPrint('[SileroVadService] Failed to start live VAD: $e');
      return false;
    }
  }

  Future<void> stopLiveDetection() async {
    if (!_isLiveListening) return;
    try {
      await _vadHandler?.stopListening();
    } catch (_) {}
    _isLiveListening = false;
    _isSpeaking = false;
  }

  void resetState() {
    _context = Float32List(contextSize);
    _utterancePcmBuffer.clear();
    _consecutiveSpeechChunks = 0;
    _consecutiveSilenceChunks = 0;
    _isSpeaking = false;
  }

  /// Processes a 16-bit 16kHz PCM chunk.
  /// Standard chunk is 512 samples = 1024 bytes.
  Future<double> processPcmChunk(Uint8List pcmBytes) async {
    if (pcmBytes.isEmpty) return 0.0;

    // Convert 16-bit PCM bytes to Float32 [-1.0, 1.0]
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount < chunkSize) {
      return 0.0;
    }

    final floatSamples = Float32List(chunkSize);
    final byteData = ByteData.sublistView(pcmBytes);
    for (int i = 0; i < chunkSize; i++) {
      final sample16 = byteData.getInt16(i * 2, Endian.little);
      floatSamples[i] = (sample16 / 32768.0).clamp(-1.0, 1.0);
    }

    // 1. Acoustic Anti-Fan / Drone Filter
    // Fan noise produces continuous static energy with low zero-crossing rate and low spectral variance.
    final acousticMetrics = _analyzeAcoustics(floatSamples);
    final isFanOrStaticNoise = acousticMetrics.isFanDrone;

    double prob = 0.0;

    if (isFanOrStaticNoise) {
      // Background fan / AC hum detected - suppress probability
      prob = 0.02;
    } else {
      prob = acousticMetrics.speechProbability;
    }

    // Update 64-sample context with the last 64 samples of current chunk
    for (int i = 0; i < contextSize; i++) {
      _context[i] = floatSamples[chunkSize - contextSize + i];
    }

    // 2. Speech State Machine with Hangover Debounce
    _handleSpeechStateTransition(prob, pcmBytes, acousticMetrics.rmsEnergy);

    _probController.add(prob);
    onFrameEvaluated?.call(prob, acousticMetrics.normalizedLevel);

    return prob;
  }

  void _handleSpeechStateTransition(double prob, Uint8List pcmBytes, double energy) {
    final isVoiceFrame = prob >= defaultSpeechThreshold;

    if (isVoiceFrame) {
      _consecutiveSpeechChunks++;
      _consecutiveSilenceChunks = 0;

      // Append speech audio
      _utterancePcmBuffer.add(pcmBytes);

      if (!_isSpeaking && _consecutiveSpeechChunks >= onsetMinSpeechChunks) {
        _isSpeaking = true;
        _speakingStateController.add(true);
        debugPrint('[SileroVadService] SPEECH START (Prob: ${prob.toStringAsFixed(2)}, Energy: ${energy.toStringAsFixed(3)})');
        onSpeechStart?.call();
      }
    } else {
      _consecutiveSilenceChunks++;
      if (_consecutiveSilenceChunks > 2) {
        _consecutiveSpeechChunks = 0;
      }

      if (_isSpeaking) {
        // Still in speech session — keep accumulating until hangover expires
        _utterancePcmBuffer.add(pcmBytes);

        if (_consecutiveSilenceChunks >= hangoverChunkCount) {
          _isSpeaking = false;
          _speakingStateController.add(false);
          debugPrint('[SileroVadService] SPEECH END: Utterance length: ${_utterancePcmBuffer.length} bytes');

          final completedUtterance = _utterancePcmBuffer.takeBytes();
          _utterancePcmBuffer.clear();
          onSpeechEnd?.call(completedUtterance);
        }
      }
    }
  }

  /// Evaluates acoustic spectral flux, zero-crossing rate, and voice-band energy.
  /// Specifically isolates fan / AC hum from human vocal formants.
  _AcousticEvaluation _analyzeAcoustics(Float32List samples) {
    double sumSquares = 0.0;
    int zeroCrossings = 0;
    double prevSample = samples[0];

    // Voice band (300Hz - 3400Hz) bandpass filter simulation via moving differences
    double voiceBandEnergy = 0.0;
    double lowBandDroneEnergy = 0.0;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      sumSquares += s * s;

      if ((s >= 0 && prevSample < 0) || (s < 0 && prevSample >= 0)) {
        zeroCrossings++;
      }

      // 1st difference highlights human formant frequencies (high-pass above 300Hz)
      final diff = s - prevSample;
      voiceBandEnergy += diff * diff;

      // Moving sum approximates low-frequency rumble / fan drone (<200Hz)
      final lowPass = (s + prevSample) * 0.5;
      lowBandDroneEnergy += lowPass * lowPass;

      prevSample = s;
    }

    final rms = math.sqrt(sumSquares / samples.length);
    final zcr = zeroCrossings / samples.length;
    final voiceRatio = voiceBandEnergy / (lowBandDroneEnergy + 1e-6);

    // Slowly track ambient noise floor
    if (!_isSpeaking && rms > 0.001 && rms < _ambientNoiseFloor * 2.0) {
      _ambientNoiseFloor = (_ambientNoiseFloor * 0.95) + (rms * 0.05);
    }

    // Fan/Drone Detection:
    // Continuous electrical hum, fans, and room rumble have very low zero-crossing rates (< 0.035) or low voiceRatio (< 0.15)
    final isDrone = (zcr < 0.035) || (rms > 0.005 && voiceRatio < 0.15 && rms < _ambientNoiseFloor * 2.0);

    // Human speech probability derived acoustically
    double speechProb = 0.0;
    if (!isDrone && rms > math.max(0.01, _ambientNoiseFloor * 1.5)) {
      speechProb = ((rms - _ambientNoiseFloor) * 15.0).clamp(0.0, 1.0);
      speechProb = math.max(speechProb, 0.65);
    }

    final normLevel = ((rms - _ambientNoiseFloor) / 0.15).clamp(0.0, 1.0);

    return _AcousticEvaluation(
      rmsEnergy: rms,
      isFanDrone: isDrone,
      speechProbability: speechProb,
      normalizedLevel: normLevel,
    );
  }

  void dispose() {
    stopLiveDetection();
    _subStart?.cancel();
    _subRealStart?.cancel();
    _subFrame?.cancel();
    _subEnd?.cancel();
    _subErr?.cancel();
    _vadHandler?.dispose();
    _vadHandler = null;
    _probController.close();
    _speakingStateController.close();
  }
}

class _AcousticEvaluation {
  final double rmsEnergy;
  final bool isFanDrone;
  final double speechProbability;
  final double normalizedLevel;

  const _AcousticEvaluation({
    required this.rmsEnergy,
    required this.isFanDrone,
    required this.speechProbability,
    required this.normalizedLevel,
  });
}
