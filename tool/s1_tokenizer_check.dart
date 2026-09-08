// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:repp/ai/audio/s1_tokenizer.dart';

Future<void> main() async {
  final json = jsonDecode(
    await File(
      'C:\\Users\\harip\\AppData\\Local\\Temp\\opencode\\s1-tokenizer.json',
    ).readAsString(),
  ) as Map<String, dynamic>;
  final tok = S1Tokenizer.fromJson(json);

  void check(String label, Object actual, Object expected) {
    final ok = '$actual' == '$expected';
    print('${ok ? 'PASS' : 'FAIL'} $label: $actual');
    if (!ok) exitCode = 1;
  }

  check('hello', tok.encode('Hello world'), [9707, 1879]);
  check(
    'scratch',
    tok.encode('abc scratch that, i want 3 sets of 10'),
    [13683, 18778, 429, 11, 600, 1366, 220, 18, 7289, 315, 220, 16, 15],
  );
  check('decode', tok.decode([9707, 1879]), 'Hello world');
  check('specials', tok.encode('<|im_start|>system'), [151644, 8948]);
  check(
    'decode-specials',
    tok.decode([151644, 8948, 198, 21553]),
    'system\n championship',
  );
  final uni = tok.encode('caf\u00e9 na\u00efve \u{1F4AA} 100kg');
  check('unicode', uni, [924, 58858, 94880, 586, 63039, 103, 220, 16, 15, 15, 7351]);
  check('roundtrip', tok.decode(uni), 'caf\u00e9 na\u00efve \u{1F4AA} 100kg');
  check('eos', tok.eosId, 151645);
}
