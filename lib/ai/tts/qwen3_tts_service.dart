import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../local_llm_service.dart';

/// Qwen3-TTS On-Device Speech Synthesis Service.
/// Communicates with native Qwen3-TTS engine via MethodChannel and streams
/// synthesized audio through just_audio.
class Qwen3TtsService {
  static final Qwen3TtsService _instance = Qwen3TtsService._internal();
  factory Qwen3TtsService() => _instance;
  Qwen3TtsService._internal();

  static const MethodChannel _channel = MethodChannel('com.repp.repp/qwen3_tts');

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _sentenceQueue = [];
  StringBuffer _streamBuffer = StringBuffer();
  bool _isPlaying = false;
  bool _isDisposed = false;

  void Function(bool isSpeaking)? onSpeakingStateChanged;

  // Energetic, motivating gym trainer voice prompt for Qwen3-TTS
  static const String gymTrainerVoicePrompt =
      'Speak in an intense, authoritative, high-energy gym trainer voice with crisp commands, fierce motivation, and urgency. Push the athlete to stay locked in and maintain strict form.';

  bool _initialized = false;
  bool _nativeEngineAvailable = false;
  bool _engineInitialized = false;
  bool get isNativeEngineAvailable => _nativeEngineAvailable;

  Future<void> initialize({String? tokenizerPath, String? talkerPath}) async {
    if (!_initialized) {
      _initialized = true;

      // Listen for PCM/WAV playback completion (native Qwen3 path)
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _playNext();
        }
      });

      // Listen for native TTS completion via MethodChannel when each sentence finishes.
      // Without this, _isPlaying is never reset and the sentence queue stalls silently.
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onTtsComplete') {
          if (_isPlaying) {
            _isPlaying = false;
            _playNext();
          }
        }
      });
    }

    if (Platform.isAndroid && !_engineInitialized) {
      try {
        final available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
        _nativeEngineAvailable = available;

        if (tokenizerPath == null || talkerPath == null) {
          final talker = await ModelDownloadService().ttsTalkerFile;
          final tokenizer = await ModelDownloadService().ttsTokenizerFile;
          if (await talker.exists() && await tokenizer.exists()) {
            tokenizerPath = tokenizer.path;
            talkerPath = talker.path;
          }
        }

        if (tokenizerPath != null && talkerPath != null) {
          final res = await _channel.invokeMethod('init', {
            'tokenizerPath': tokenizerPath,
            'talkerPath': talkerPath,
          });
          if (res == true) {
            _engineInitialized = true;
          }
        }
      } catch (e) {
        debugPrint('[Qwen3TtsService] Native engine init notice: $e');
      }
    }
  }

  /// Appends streaming token chunks from LLM and enqueues completed sentences
  void appendChunk(String chunk) {
    _streamBuffer.write(chunk);

    // Ignore content inside thinking tags
    final raw = _streamBuffer.toString();
    if (raw.contains('<thought>') && !raw.contains('</thought>')) {
      return;
    }
    if (raw.contains('<think>') && !raw.contains('</think>')) {
      return;
    }

    String text = raw
        .replaceAll(RegExp(r'<(?:thought|think)>[\s\S]*?<\/(?:thought|think)>'), '');

    while (true) {
      final match = RegExp(r'^(.*?[.!?\n]+)([\s\S]*)$', dotAll: true).firstMatch(text);
      if (match != null) {
        final sentence = match.group(1)?.trim();
        final rest = match.group(2) ?? '';
        text = rest;
        if (sentence != null && sentence.isNotEmpty) {
          _enqueue(sentence);
        }
      } else {
        break;
      }
    }
    _streamBuffer = StringBuffer(text);
  }

  /// Called when the LLM finishes streaming to flush remaining text
  void finish() {
    final remaining = _streamBuffer
        .toString()
        .replaceAll(RegExp(r'<(?:thought|think)>[\s\S]*?<\/(?:thought|think)>'), '')
        .trim();
    _streamBuffer.clear();
    if (remaining.isNotEmpty) {
      _enqueue(remaining);
    }
  }

  /// Speaks a full block of text (splits into sentences for chained playback)
  void speakText(String fullText) {
    stop();
    final clean = _cleanMarkdown(fullText);
    if (clean.isEmpty) return;

    final sentences = clean.split(RegExp(r'(?<=[.!?\n])\s+'));
    for (final s in sentences) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) {
        _sentenceQueue.add(trimmed);
      }
    }
    if (!_isPlaying && _sentenceQueue.isNotEmpty) {
      _playNext();
    }
  }

  void _enqueue(String rawSentence) {
    final clean = _cleanMarkdown(rawSentence);
    if (clean.isEmpty) return;
    _sentenceQueue.add(clean);
    if (!_isPlaying) {
      _playNext();
    }
  }

  String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'<(?:thought|think)>[\s\S]*?<\/(?:thought|think)>'), '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'[*#_`~]'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
        .trim();
  }

  Future<void> _playNext() async {
    if (_sentenceQueue.isEmpty) {
      _isPlaying = false;
      onSpeakingStateChanged?.call(false);
      return;
    }

    _isPlaying = true;
    onSpeakingStateChanged?.call(true);
    final sentence = _sentenceQueue.removeAt(0);

    try {
      // 1. Synthesize audio via native Qwen3-TTS / Android bridge
      Uint8List? pcmBytes;
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<Uint8List>('synthesize', {
          'text': sentence,
          'voicePrompt': gymTrainerVoicePrompt,
        });
        pcmBytes = result;
      }

      if (pcmBytes != null && pcmBytes.isNotEmpty) {
        await _playPcmBytes(pcmBytes);
      } else {
        debugPrint('[Qwen3TtsService] Native synthesis returned null. 0 fallbacks allowed.');
        _isPlaying = false;
        _playNext();
      }
    } catch (e) {
      debugPrint('[Qwen3TtsService] Synthesis error: $e');
      _isPlaying = false;
      _playNext();
    }
  }

  /// Converts raw 24kHz 16-bit PCM to a temporary WAV file and plays via just_audio
  Future<void> _playPcmBytes(Uint8List pcmBytes) async {
    try {
      final wavBytes = _addWavHeader(pcmBytes, sampleRate: 24000, numChannels: 1);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_chunk_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes, flush: true);

      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();

      // Clean up after playback
      tempFile.delete().catchError((_) => tempFile);
    } catch (e) {
      debugPrint('[Qwen3TtsService] Playback error: $e');
      _isPlaying = false;
      _playNext();
    }
  }

  /// Appends standard 44-byte RIFF/WAV header to raw 16-bit PCM data
  Uint8List _addWavHeader(Uint8List pcmData, {required int sampleRate, required int numChannels}) {
    final byteRate = sampleRate * numChannels * 2;
    final totalDataLen = pcmData.length;
    final totalAudioLen = totalDataLen + 36;
    final header = Uint8List(44);
    final view = ByteData.sublistView(header);

    // RIFF chunk
    header.setRange(0, 4, 'RIFF'.codeUnits);
    view.setUint32(4, totalAudioLen, Endian.little);
    header.setRange(8, 12, 'WAVE'.codeUnits);

    // fmt subchunk
    header.setRange(12, 16, 'fmt '.codeUnits);
    view.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    view.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, numChannels * 2, Endian.little); // BlockAlign
    view.setUint16(34, 16, Endian.little); // BitsPerSample (16)

    // data subchunk
    header.setRange(36, 40, 'data'.codeUnits);
    view.setUint32(40, totalDataLen, Endian.little);

    final wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header);
    wav.setRange(44, wav.length, pcmData);
    return wav;
  }

  /// Immediately interrupts speech playback and flushes the queue
  Future<void> stop() async {
    _streamBuffer.clear();
    _sentenceQueue.clear();
    _isPlaying = false;

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    }

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    onSpeakingStateChanged?.call(false);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    stop();
    _audioPlayer.dispose();
  }
}
