import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_normalizer_service.dart';
import 'silero_vad_service.dart';
import 'whisper_asr_service.dart';
import '../tts/qwen3_tts_service.dart';

/// Lifecycle state for full-duplex conversational voice mode
enum OmniDuplexState {
  idle,
  listening,
  userSpeaking,
  thinking,
  speakingCoach,
}

/// Orchestrates the full-duplex conversational voice loop using Silero VAD v5 + Whisper Tiny.
/// Audio is captured via 16kHz PCM stream directly through AudioRecorder.
/// Rejects fan noise, AC hum, and external room rumble.
/// ZERO OS fallbacks: No OS STT, No OS VAD, No OS TTS.
class OmniDuplexController {
  static final OmniDuplexController _instance = OmniDuplexController._internal();
  factory OmniDuplexController() => _instance;
  OmniDuplexController._internal();

  final SpeechNormalizerService _normalizer = SpeechNormalizerService();
  final Qwen3TtsService _tts = Qwen3TtsService();
  final SileroVadService _vad = SileroVadService();
  final WhisperAsrService _whisper = WhisperAsrService();

  OmniDuplexState _state = OmniDuplexState.idle;
  OmniDuplexState get state => _state;

  bool isTtsMuted = false;

  final StreamController<OmniDuplexState> _stateController =
      StreamController<OmniDuplexState>.broadcast();
  Stream<OmniDuplexState> get stateStream => _stateController.stream;

  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  final StreamController<String> _liveSpokenTextController =
      StreamController<String>.broadcast();
  Stream<String> get liveSpokenTextStream => _liveSpokenTextController.stream;

  final List<String> _pendingUtterances = [];
  Timer? _coalesceDispatchTimer;
  Timer? _voiceUnloadTimer;
  bool _isDispatching = false;

  VoidCallback? _cancelGeneration;
  Future<void> Function(String prompt, void Function(String chunk) onChunk)? onSendPrompt;

  String _lastProcessedUtterance = '';

  void initialize({
    required Future<void> Function(String prompt, void Function(String chunk) onChunk) sendPromptHandler,
  }) {
    onSendPrompt = sendPromptHandler;

    _tts.onSpeakingStateChanged = (isSpeaking) {
      if (isTtsMuted) return;
      if (isSpeaking && _state != OmniDuplexState.userSpeaking) {
        _setState(OmniDuplexState.speakingCoach);
      } else if (!isSpeaking && _state == OmniDuplexState.speakingCoach) {
        _setState(OmniDuplexState.listening);
      }
    };

    // Wire Silero VAD hooks
    _vad.onSpeechStart = () {
      if (_state == OmniDuplexState.speakingCoach || _state == OmniDuplexState.thinking) {
        debugPrint('[OmniDuplex] BARGE-IN: User spoke while coach was talking. Stopping TTS.');
        _tts.stop();
      }
      if (_state != OmniDuplexState.userSpeaking && _state != OmniDuplexState.idle) {
        _setState(OmniDuplexState.userSpeaking);
      }
    };

    _vad.onSpeechEndSamples = (samples) async {
      debugPrint('[OmniDuplex] Silero VAD speech ended (${samples.length} samples). Transcribing via whisper.cpp...');
      if (_state == OmniDuplexState.idle) return;

      final words = await _whisper.transcribeSamples(samples);
      if (words.isNotEmpty && words != _lastProcessedUtterance) {
        _lastProcessedUtterance = words;
        _liveSpokenTextController.add(words);
        _enqueueUserUtterance(words);
      } else if (_state == OmniDuplexState.userSpeaking) {
        _setState(OmniDuplexState.listening);
      }
    };

    _vad.onSpeechEnd = (utterancePcm) async {
      debugPrint('[OmniDuplex] Silero VAD detected speech end (${utterancePcm.length} bytes). Transcribing via whisper.cpp...');
      if (_state == OmniDuplexState.idle) return;

      final words = await _whisper.transcribePcm(utterancePcm);
      if (words.isNotEmpty && words != _lastProcessedUtterance) {
        _lastProcessedUtterance = words;
        _liveSpokenTextController.add(words);
        _enqueueUserUtterance(words);
      } else if (_state == OmniDuplexState.userSpeaking) {
        _setState(OmniDuplexState.listening);
      }
    };

    _vad.onFrameEvaluated = (probability, soundLevel) {
      if (_state == OmniDuplexState.userSpeaking) {
        _soundLevelController.add(soundLevel);
      } else if (_state == OmniDuplexState.listening) {
        if (probability >= SileroVadService.defaultSpeechThreshold) {
          _soundLevelController.add(soundLevel);
        } else {
          _soundLevelController.add(0.0);
        }
      }
    };
  }

  void _setState(OmniDuplexState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(_state);
  }

  Future<bool> startDuplexMode() async {
    // 1. Cancel any active 5-minute keep-alive unload timer
    if (_voiceUnloadTimer != null) {
      debugPrint('[OmniDuplex] Re-entering voice chat within 5 mins. Voice models are still hot!');
      _voiceUnloadTimer?.cancel();
      _voiceUnloadTimer = null;
    }

    if (_state != OmniDuplexState.idle) return true;

    _lastProcessedUtterance = '';

    await _vad.initialize();
    await _whisper.initialize();

    final started = await _vad.startLiveDetection();
    if (!started) {
      debugPrint('[OmniDuplex] Failed to start live Silero VAD.');
      return false;
    }

    _setState(OmniDuplexState.listening);
    debugPrint('[OmniDuplex] Silero V5 VAD (Option 2: Local Assets) + whisper.cpp active (Zero OS fallbacks).');
    return true;
  }

  Future<void> stopDuplexMode() async {
    _setState(OmniDuplexState.idle);

    _coalesceDispatchTimer?.cancel();
    _coalesceDispatchTimer = null;
    _pendingUtterances.clear();
    _isDispatching = false;
    _lastProcessedUtterance = '';

    _cancelGeneration?.call();
    _cancelGeneration = null;
    await _tts.stop();
    await _vad.stopLiveDetection();
    _vad.resetState();

    _soundLevelController.add(0.0);
    _liveSpokenTextController.add('');

    // 2. Start 5-minute keep-alive grace period before unloading voice models
    _scheduleVoiceUnloadTimer();
  }

  void _scheduleVoiceUnloadTimer() {
    _voiceUnloadTimer?.cancel();
    _voiceUnloadTimer = Timer(const Duration(minutes: 5), () {
      debugPrint('[OmniDuplex] 5 minutes idle elapsed since leaving voice chat. Unloading voice stack (Whisper, VAD, TTS) to revert to State 1...');
      _unloadVoiceStack();
    });
  }

  void _unloadVoiceStack() {
    _voiceUnloadTimer?.cancel();
    _voiceUnloadTimer = null;
    _vad.dispose();
    _whisper.dispose();
    _tts.dispose();
    debugPrint('[OmniDuplex] Voice stack successfully unloaded. Reverted to State 1 (Gemma only).');
  }

  void _enqueueUserUtterance(String rawUtterance) {
    final normalized = _normalizer.normalize(rawUtterance);
    if (normalized.trim().isEmpty) {
      if (_state == OmniDuplexState.userSpeaking) {
        _setState(OmniDuplexState.listening);
      }
      return;
    }

    debugPrint('[OmniDuplex] Enqueueing utterance: "$normalized"');
    _pendingUtterances.add(normalized);
    _scheduleCoalescedDispatch();
  }

  void _scheduleCoalescedDispatch() {
    _coalesceDispatchTimer?.cancel();
    _coalesceDispatchTimer = Timer(const Duration(milliseconds: 700), () {
      if (_pendingUtterances.isNotEmpty) {
        if (!_isDispatching) {
          _dispatchCoalescedPrompt();
        } else {
          _setState(OmniDuplexState.thinking);
        }
      }
    });
  }

  Future<void> _dispatchCoalescedPrompt() async {
    if (_pendingUtterances.isEmpty || _isDispatching) return;

    _isDispatching = true;
    _setState(OmniDuplexState.thinking);

    final fullPrompt = _pendingUtterances.join('. ');
    _pendingUtterances.clear();

    debugPrint('[OmniDuplex] Dispatching to Gemma: "$fullPrompt"');
    _liveSpokenTextController.add(fullPrompt);

    bool isCancelled = false;
    _cancelGeneration = () {
      isCancelled = true;
    };

    try {
      if (onSendPrompt != null) {
        await onSendPrompt!(
          fullPrompt,
          (chunk) {
            if (!isCancelled && _state != OmniDuplexState.idle && !isTtsMuted) {
              _tts.appendChunk(chunk);
            }
          },
        );
      }

      if (!isCancelled && _state != OmniDuplexState.idle && !isTtsMuted) {
        _tts.finish();
      }
    } catch (e) {
      debugPrint('[OmniDuplex] Generation error: $e');
    } finally {
      _isDispatching = false;
      _cancelGeneration = null;
      _lastProcessedUtterance = '';

      if (_pendingUtterances.isNotEmpty && _state != OmniDuplexState.idle) {
        _dispatchCoalescedPrompt();
      } else if (_state == OmniDuplexState.thinking || _state == OmniDuplexState.userSpeaking) {
        _setState(OmniDuplexState.listening);
      }
    }
  }

  void dispose() {
    _voiceUnloadTimer?.cancel();
    _voiceUnloadTimer = null;
    stopDuplexMode();
    _vad.dispose();
    _whisper.dispose();
    _tts.dispose();
    _stateController.close();
    _soundLevelController.close();
    _liveSpokenTextController.close();
  }
}
