import 'package:flutter_test/flutter_test.dart';
import 'package:repp/ai/audio/s1_tokenizer.dart';

/// Synthetic mini-BPE fixture exercising codec mechanics without the 9MB
/// real tokenizer.json. Golden vectors against the reference implementation
/// live in tool/s1_tokenizer_check.dart (dev-only, needs the model file).
Map<String, dynamic> miniFixture() {
  // Byte-level vocab slice: 'a', 'b', ' ' mapped GPT-2 style, plus merges.
  // ' ' (0x20) -> U+0120 (288), 'a'/'b' stay literal (printable).
  return {
    'model': {
      'type': 'BPE',
      'vocab': {
        'a': 0,
        'b': 1,
        '\u0120': 2, // space
        'ab': 3,
        '\u0120a': 4,
        '<|endoftext|>': 5,
      },
      // Pair-list format (as shipped in HF tokenizers files).
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
  test('BPE merges follow rank order', () {
    final tok = S1Tokenizer.fromJson(miniFixture());
    // ' ab' -> pieces ' ', 'ab' -> ' ' maps to U+0120, 'ab' merges a+b.
    expect(tok.encode(' ab'), [2, 3]);
  });

  test('special tokens split longest-match and survive roundtrip', () {
    final tok = S1Tokenizer.fromJson(miniFixture());
    expect(tok.encode('<|im_start|>ab'), [101, 3]);
    expect(tok.decode([101, 3]), 'ab');
    // '<|im_end|>' is added-only (not in vocab) — same as the real file.
    expect(tok.encode('x<|im_end|>'), isNotEmpty);
  });

  test('in-vocab text roundtrips byte-exact', () {
    final tok = S1Tokenizer.fromJson(miniFixture());
    const text = ' ab ab';
    expect(tok.decode(tok.encode(text)), text);
  });

  test('out-of-vocab bytes never crash the codec', () {
    final tok = S1Tokenizer.fromJson(miniFixture());
    // Mini fixture lacks full 256-byte coverage (the real 151k vocab has
    // it — proven by tool/s1_tokenizer_check.dart golden vectors).
    final ids = tok.encode('lifter \u{1F4AA}');
    expect(ids, isNotEmpty);
    expect(() => tok.decode(ids), returnsNormally);
  });

  test('empty input encodes empty', () {
    final tok = S1Tokenizer.fromJson(miniFixture());
    expect(tok.encode(''), isEmpty);
    expect(tok.decode([]), isEmpty);
  });
}
