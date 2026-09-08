import 'dart:convert';

/// Minimal Qwen3 byte-level BPE codec for the S1-mini ONNX bundle.
///
/// Reads the stock HF `tokenizer.json` (BPE + Qwen split regex + ByteLevel,
/// NFC normalizer, 26 added specials) and implements greedy longest-match
/// special splitting, regex pre-tokenization, byte-level encoding and the
/// BPE merge loop. Pure Dart, no native code — fully unit-testable.
///
/// Limits vs the reference implementation:
/// - NFC normalization is a no-op (Dart SDK has no Unicode normalization;
///   gym-voice ASCII input is unaffected).
/// - `byte_fallback` semantics equal the reference for this file
///   (`byte_fallback: false` with full 256-byte vocab coverage).
class S1Tokenizer {
  S1Tokenizer._({
    required Map<String, int> vocab,
    required Map<String, int> ranks,
    required Map<int, String> idToToken,
    required Set<int> specialIds,
    required this.eosId,
  })  : _vocab = vocab,
        _ranks = ranks,
        _idToToken = idToToken,
        _specialIds = specialIds;

  /// Qwen3 split pattern from this bundle's tokenizer.json.
  static final RegExp _splitPattern = RegExp(
    r"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+",
    unicode: true,
    caseSensitive: false,
  );

  final Map<String, int> _vocab;
  final Map<String, int> _ranks;
  final Map<int, String> _idToToken;
  final Set<int> _specialIds;

  /// Added special token strings (from `added_tokens`), longest-match split.
  List<String> _specialStrings = const [];

  /// Special string → id (specials live outside `vocab`).
  Map<String, int> _specialStringToId = const {};

  /// `<|im_end|>` id — generation stop token.
  final int eosId;

  late final Map<int, int> _byteToUnicode = _buildBytesToUnicode();
  late final Map<int, int> _unicodeToByte = {
    for (final e in _byteToUnicode.entries) e.value: e.key,
  };

  static Map<int, int> _buildBytesToUnicode() {
    final bs = <int>[
      for (var b = 0x21; b <= 0x7E; b++) b,
      for (var b = 0xA1; b <= 0xAC; b++) b,
      for (var b = 0xAE; b <= 0xFF; b++) b,
    ];
    final cs = List<int>.from(bs);
    var n = 0;
    for (var b = 0; b < 256; b++) {
      if (!bs.contains(b)) {
        bs.add(b);
        cs.add(256 + n);
        n++;
      }
    }
    return {for (var i = 0; i < bs.length; i++) bs[i]: cs[i]};
  }

  /// Loads from a decoded tokenizer.json map.
  factory S1Tokenizer.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>;
    final vocab = (model['vocab'] as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    final mergesRaw = (model['merges'] as List).cast<dynamic>();
    final ranks = <String, int>{};
    for (var i = 0; i < mergesRaw.length; i++) {
      final entry = mergesRaw[i];
      // HF tokenizers BPE stores merges as ["left", "right"] pairs.
      final pair = entry is List
          ? '${entry[0]} ${entry[1]}'
          : entry.toString();
      ranks[pair] = i;
    }
    final idToToken = {for (final e in vocab.entries) e.value: e.key};
    final added = (json['added_tokens'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final specialIds = <int>{};
    final specialStrings = <String>[];
    final specialStringToId = <String, int>{};
    for (final tok in added) {
      if (tok['special'] == true) {
        final id = (tok['id'] as num).toInt();
        specialIds.add(id);
        final content = tok['content'] as String?;
        if (content != null && content.isNotEmpty) {
          specialStrings.add(content);
          specialStringToId[content] = id;
        }
      }
    }
    final eosId = vocab['<|im_end|>'] ?? 151645;
    final codec = S1Tokenizer._(
      vocab: vocab,
      ranks: ranks,
      idToToken: idToToken,
      specialIds: specialIds,
      eosId: eosId,
    );
    codec._specialStrings = specialStrings;
    codec._specialStringToId = specialStringToId;
    return codec;
  }

  /// Splits [text] into pieces: longest-match added specials first, then
  /// the Qwen regex on the gaps (Isolated behavior).
  List<String> _preTokenize(String text) {
    final specials = _specialStrings.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pieces = <String>[];
    var cursor = 0;
    while (cursor < text.length) {
      var matchedSpecial = false;
      for (final special in specials) {
        if (special.isNotEmpty && text.startsWith(special, cursor)) {
          pieces.add(special);
          cursor += special.length;
          matchedSpecial = true;
          break;
        }
      }
      if (matchedSpecial) continue;
      var nextSpecial = text.length;
      for (final special in specials) {
        if (special.isEmpty) continue;
        final idx = text.indexOf(special, cursor);
        if (idx >= 0 && idx < nextSpecial) nextSpecial = idx;
      }
      final gap = text.substring(cursor, nextSpecial);
      for (final m in _splitPattern.allMatches(gap)) {
        pieces.add(m.group(0)!);
      }
      cursor = nextSpecial;
    }
    return pieces;
  }

  String _bytesToUnicode(String piece) {
    final bytes = utf8.encode(piece);
    return String.fromCharCodes(bytes.map((b) => _byteToUnicode[b]!));
  }

  List<int> _bpe(String token) {
    if (token.length <= 1) {
      return [_vocab[token] ?? _vocab['<|endoftext|>'] ?? 151643];
    }
    var parts = token.split('');
    while (true) {
      var bestRank = 1 << 30;
      var bestIdx = -1;
      for (var i = 0; i < parts.length - 1; i++) {
        final pair = '${parts[i]} ${parts[i + 1]}';
        final rank = _ranks[pair];
        if (rank != null && rank < bestRank) {
          bestRank = rank;
          bestIdx = i;
        }
      }
      if (bestIdx < 0) break;
      final merged = parts[bestIdx] + parts[bestIdx + 1];
      parts = [...parts.sublist(0, bestIdx), merged, ...parts.sublist(bestIdx + 2)];
    }
    return [
      for (final p in parts) _vocab[p] ?? _vocab['<|endoftext|>'] ?? 151643,
    ];
  }

  /// Encodes [text] to token ids (golden-tested against the reference).
  List<int> encode(String text) {
    final ids = <int>[];
    for (final piece in _preTokenize(text)) {
      final specialId = _specialStringToId[piece];
      if (specialId != null) {
        ids.add(specialId);
        continue;
      }
      ids.addAll(_bpe(_bytesToUnicode(piece)));
    }
    return ids;
  }

  /// Decodes [ids] to text, skipping special tokens.
  String decode(List<int> ids) {
    final buf = StringBuffer();
    final byteAcc = <int>[];
    void flushBytes() {
      if (byteAcc.isEmpty) return;
      buf.write(utf8.decode(byteAcc, allowMalformed: true));
      byteAcc.clear();
    }

    for (final id in ids) {
      if (_specialIds.contains(id)) {
        flushBytes();
        continue;
      }
      final token = _idToToken[id];
      if (token == null) continue;
      for (final rune in token.runes) {
        final byte = _unicodeToByte[rune];
        if (byte != null) {
          byteAcc.add(byte);
        } else {
          flushBytes();
          buf.writeCharCode(rune);
        }
      }
    }
    flushBytes();
    return buf.toString();
  }
}
