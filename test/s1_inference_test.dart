import 'package:flutter_test/flutter_test.dart';
import 'package:repp/ai/audio/s1_cleanup_service.dart';
import 'package:repp/ai/audio/s1_ort_ffi.dart';
import 'package:repp/ai/audio/s1_tokenizer.dart';

Map<String, dynamic> miniFixture() {
  return {
    'model': {
      'type': 'BPE',
      'vocab': {
        'a': 0,
        'b': 1,
        '\u0120': 2,
        'ab': 3,
        '\u0120a': 4,
        '<|endoftext|>': 5,
      },
      'merges': [
        ['a', 'b'],
        ['\u0120', 'a'],
      ],
    },
    'added_tokens': [
      {
        'id': 100,
        'content': '<|im_end|>',
        'single_word': false,
        'lstrip': false,
        'rstrip': false,
        'normalized': false,
        'special': true,
      },
      {
        'id': 101,
        'content': '<|im_start|>',
        'single_word': false,
        'lstrip': false,
        'rstrip': false,
        'normalized': false,
        'special': true,
      },
    ],
  };
}

void main() {
  group('fp16 bridge', () {
    test('roundtrips representative values', () {
      for (final v in [0.0, 1.0, -1.0, 0.5, 100.0, 0.001, -273.15]) {
        expect(fp16BitsToFloat32(floatToFp16Bits(v)), closeTo(v, v.abs() * 0.002 + 1e-4));
      }
    });

    test('zero stays zero, extremes stay finite', () {
      expect(floatToFp16Bits(0.0), 0);
      expect(fp16BitsToFloat32(0), 0.0);
      expect(fp16BitsToFloat32(floatToFp16Bits(1e10)).isFinite, isTrue);
    });
  });

  group('S1IoLayout.classify', () {
    test('discovers logits + aligned past/present + mask', () {
      final layout = S1IoLayout.classify(
        ['input_ids', 'attention_mask', 'past.1.v', 'past.0.k', 'past.0.v', 'past.1.k'],
        ['logits', 'present.1.v', 'present.0.k', 'present.0.v', 'present.1.k'],
      );
      expect(layout, isNotNull);
      expect(layout!.logitsOutput, 'logits');
      expect(layout.maskInput, 'attention_mask');
      expect(layout.pastInputs.length, 4);
      expect(layout.presentOutputs.length, 4);
    });

    test('rejects missing input_ids / logits / cache', () {
      expect(S1IoLayout.classify(['x'], ['logits']), isNull);
      expect(S1IoLayout.classify(['input_ids'], ['a', 'b']), isNull);
      expect(
        S1IoLayout.classify(
          ['input_ids', 'past.0'],
          ['logits', 'present.0', 'present.1'],
        ),
        isNull,
      );
    });
  });

  group('S1 prompt', () {
    test('wraps raw text in system/user/assistant turns', () {
      final tok = S1Tokenizer.fromJson(miniFixture());
      final ids = S1CleanupService.buildPromptIds(tok, 'ab');
      // Special openers survive; long prompts truncate to the 256 tail.
      expect(ids, contains(101));
      expect(ids.length, lessThanOrEqualTo(256));
      expect(ids.length, greaterThan(10));
    });
  });

  group('S1CleanupService passthrough', () {
    test('empty input short-circuits without session', () async {
      expect(await S1CleanupService().cleanup('   '), isEmpty);
    });
  });
}
