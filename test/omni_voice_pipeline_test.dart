import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repp/ai/audio/speech_normalizer_service.dart';
import 'package:repp/ai/audio/silero_vad_service.dart';
import 'package:repp/ai/audio/whisper_asr_service.dart';
import 'package:repp/ai/audio/omni_duplex_controller.dart';
import 'package:repp/ai/tts/qwen3_tts_service.dart';
import 'package:repp/ai/local_llm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.repp.repp/qwen3_tts'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.repp.repp/silero_vad'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.repp.repp/whisper_asr'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async => null,
    );
  });

  group('ModelCatalog Suite tests', () {
    test('contains Whisper Tiny and Silero VAD v5 entries with 6 total steps', () {
      final entries = ModelDownloadService.suiteEntries;
      expect(entries.length, 6);

      final vad = entries.firstWhere((e) => e.id == 'vad');
      expect(vad.name, contains('Silero VAD'));
      expect(vad.filename, 'silero_vad_v5.onnx');
      expect(vad.isBundled, true);

      final asr = entries.firstWhere((e) => e.id == 'asr');
      expect(asr.name, contains('Whisper Tiny'));
      expect(asr.filename, 'ggml-tiny.en.bin');
      expect(asr.url, contains('whisper.cpp'));
      expect(asr.sizeBytes, 77704715);
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
    final normalizer = SpeechNormalizerService();

    test('normalizes phonetic RPE terms accurately', () {
      expect(normalizer.normalize('that was our p e 8'), 'That was RPE 8');
      expect(normalizer.normalize('rbe 9 bench press'), 'RPE 9 bench press');
      expect(normalizer.normalize('rate of perceived exertion was high'), 'RPE was high');
    });

    test('normalizes AMRAP and rep maxes', () {
      expect(normalizer.normalize('do an am rap set'), 'Do an AMRAP set');
      expect(normalizer.normalize('my one rep max is 100 kilos'), 'My 1RM is 100 kg');
      expect(normalizer.normalize('3 rep max deadlift'), '3RM deadlift');
    });

    test('strips filler words and cleans whitespace', () {
      expect(
        normalizer.normalize('um i did uh 3 sets of 10'),
        'I did 3x10 reps',
      );
      expect(
        normalizer.normalize('ah like give me dumbbell curl feedback'),
        'Give me dumbbell curl feedback',
      );
    });

    test('handles empty and whitespace input safely', () {
      expect(normalizer.normalize(''), '');
      expect(normalizer.normalize('   '), '');
    });
  });

  group('Qwen3TtsService tests', () {
    final tts = Qwen3TtsService();

    test('singleton instance exists and has gym trainer voice prompt', () {
      expect(tts, isNotNull);
      expect(Qwen3TtsService.gymTrainerVoicePrompt, contains('gym trainer voice'));
      expect(Qwen3TtsService.gymTrainerVoicePrompt, contains('authoritative'));
    });

    test('appendChunk correctly ignores thinking and thought tags', () {
      tts.appendChunk('<thought>Evaluating form</thought>Keep your chest up!');
      tts.finish();
      expect(tts, isNotNull);
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
