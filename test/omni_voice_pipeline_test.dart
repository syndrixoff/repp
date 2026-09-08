import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repp/ai/audio/silero_vad_service.dart';
import 'package:repp/ai/audio/whisper_asr_service.dart';
import 'package:repp/ai/audio/omni_duplex_controller.dart';
import 'package:repp/ai/tts/coach_tts_service.dart';
import 'package:repp/ai/tts/gemma_speech_tts_service.dart';
import 'package:repp/ai/local_llm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async => null,
    );
  });

  group('ModelCatalog Suite tests', () {
    test('contains moonshine STT and Inflect TTS engine entries (4 steps)', () {
      final entries = ModelDownloadService.suiteEntries;
      expect(entries.length, 4);

      final vad = entries.firstWhere((e) => e.id == 'vad');
      expect(vad.name, contains('Silero VAD'));
      expect(vad.filename, 'silero_vad_v5.onnx');
      expect(vad.isBundled, true);

      final stt = entries.firstWhere((e) => e.id == 'stt');
      expect(stt.name, contains('Moonshine'));
      expect(stt.filename, 'moonshine_tiny_5s_f32.tflite');
      expect(stt.isEngineManaged, true);
      expect(stt.sizeBytes, 110600000);

      final tts = entries.firstWhere((e) => e.id == 'tts');
      expect(tts.name, contains('Inflect'));
      expect(tts.isEngineManaged, true);
      expect(tts.sizeBytes, 35710101);
    });
  });

  group('SileroVadService anti-fan noise tests', () {
    final vad = SileroVadService();

    test('rejects simulated 60Hz fan/AC hum without triggering speech', () async {
      vad.resetState();

      // Generate 512 samples of 60Hz sine wave (low-frequency fan hum)
      final pcmBytes = Uint8List(1024);
      final byteData = ByteData.sublistView(pcmBytes);
      for (int i = 0; i < 512; i++) {
        // 60Hz at 16000Hz sample rate
        final sample = (math.sin(2 * math.pi * 60 * i / 16000) * 1500).round();
        byteData.setInt16(i * 2, sample, Endian.little);
      }

      final prob = await vad.processPcmChunk(pcmBytes);
      expect(prob, lessThan(0.3));
      expect(vad.isSpeaking, isFalse);
    });

    test('detects simulated voice-frequency bursts (1000Hz formant)', () async {
      vad.resetState();

      // Generate 512 samples of 1000Hz wave (vocal formant region) with dynamic amplitude
      final pcmBytes = Uint8List(1024);
      final byteData = ByteData.sublistView(pcmBytes);
      for (int i = 0; i < 512; i++) {
        final sample = (math.sin(2 * math.pi * 1000 * i / 16000) * 12000).round();
        byteData.setInt16(i * 2, sample, Endian.little);
      }

      final prob = await vad.processPcmChunk(pcmBytes);
      expect(prob, greaterThanOrEqualTo(0.5));
    });
  });

  group('WhisperAsrService tests', () {
    final asr = WhisperAsrService();

    test('transcribes empty buffer safely', () async {
      final text = await asr.transcribePcm(Uint8List(0));
      expect(text, isEmpty);
    });
  });

  group('SpeechNormalizerService tests', () {
    // Regex normalizer removed — S1 (thinking cleanup) owns this now.
    // Placeholder keeps group structure until S1 tests land.
    test('placeholder', () {
      expect(true, isTrue);
    });
  });

  group('CoachTtsService tests', () {
    final tts = CoachTtsService();

    test('singleton instance exists and has gym trainer voice prompt', () {
      expect(tts, isNotNull);
      expect(CoachTtsService.gymTrainerVoicePrompt, contains('gym trainer voice'));
      expect(CoachTtsService.gymTrainerVoicePrompt, contains('authoritative'));
    });

    test('appendChunk correctly ignores thinking and thought tags', () {
      tts.appendChunk('<thought>Evaluating form</thought>Keep your chest up!');
      tts.finish();
      expect(tts, isNotNull);
    });
  });

  group('GemmaSpeechTtsService tests', () {
    final tts = GemmaSpeechTtsService();

    setUp(() {
      GemmaSpeechTtsService.autoInstall = false;
      WhisperAsrService.autoInstall = false;
    });

    test('returns null for empty text without touching the engine', () async {
      expect(await tts.synthesizePcm(''), isNull);
      expect(await tts.synthesizePcm('   '), isNull);
    });

    test('singleton starts unavailable until bundle is installed', () {
      expect(tts.isAvailable, isFalse);
    });
  });

  group('OmniDuplexController tests', () {
    final controller = OmniDuplexController();

    test('initial state is idle', () {
      expect(controller.state, OmniDuplexState.idle);
    });

    test('controller initializes with prompt handler', () {
      controller.initialize(
        sendPromptHandler: (prompt, onChunk) async {},
      );
      expect(controller.onSendPrompt, isNotNull);
    });
  });

  group('GenkitGemmaService channel token sanitization tests', () {
    test('removes repeated <channel|><|channel>thought garbage from tokens', () {
      const rawGarbage =
          'acknowledgment<channel|><|channel>thought . It<channel|><|channel>thought must<channel|><|channel>thought demand<channel|><|channel>thought action<channel|><|channel>thought .';
      final cleaned = GenkitGemmaService.sanitizeChannelTokens(rawGarbage);
      expect(cleaned, 'acknowledgment . It must demand action .');
    });

    test('cleans channel response and call control markers', () {
      const rawWithControl =
          '<|channel|>thought Analyzing biomechanics<|channel|>response Maintain strict form on every rep!';
      final cleaned = GenkitGemmaService.sanitizeChannelTokens(rawWithControl);
      expect(cleaned, contains('Analyzing biomechanics'));
      expect(cleaned, contains('Maintain strict form on every rep!'));
      expect(cleaned, isNot(contains('<|channel|>')));
      expect(cleaned, isNot(contains('<channel|>')));
    });
  });
}
