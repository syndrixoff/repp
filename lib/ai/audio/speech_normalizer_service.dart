/// Speech normalization service for fitness/gym terminology and disfluency cleaning.
/// Fixes domain-specific fitness terms that speech recognition commonly misinterprets
/// and strips filler words before sending input to Gemma 4 E2B.
class SpeechNormalizerService {
  static final SpeechNormalizerService _instance = SpeechNormalizerService._internal();
  factory SpeechNormalizerService() => _instance;
  SpeechNormalizerService._internal();

  /// Disfluencies and filler words to clean out
  static final List<RegExp> _fillerWords = [
    RegExp(r'\b(?:um|umm|uh|uhh|er|err|ah|ahh)\b,?\s*', caseSensitive: false),
    RegExp(r'^(?:like|you know|i mean|so)\b,?\s*', caseSensitive: false),
  ];

  /// Normalizes transcribed speech into clear fitness command text
  String normalize(String rawSpeech) {
    if (rawSpeech.trim().isEmpty) return '';

    String cleaned = rawSpeech.trim();

    // 1. Strip disfluencies & fillers
    for (final pattern in _fillerWords) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    // 2. Domain-specific phonetic / vocabulary replacements
    // RPE terms
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b(?:our|are|hour)\s*p\s*e\s*([0-9]|10)\b', caseSensitive: false),
      (m) => 'RPE ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\br\s*p\s*e\s*([0-9]|10)\b', caseSensitive: false),
      (m) => 'RPE ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\brbe\s*([0-9]|10)\b', caseSensitive: false),
      (m) => 'RPE ${m[1]}',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\brate of perceived exertion\b', caseSensitive: false),
      'RPE',
    );

    // AMRAP
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:am\s*rap|am\s*wrap|as many reps as possible)\b', caseSensitive: false),
      'AMRAP',
    );

    // Rep maxes
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:one|1)\s*(?:rep\s*max|r\s*m)\b', caseSensitive: false),
      '1RM',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]{1,2})\s*(?:rep\s*max|r\s*m)\b', caseSensitive: false),
      (m) => '${m[1]}RM',
    );

    // PR / PB
    cleaned = cleaned.replaceAll(RegExp(r'\bp\s*r\b', caseSensitive: false), 'PR');
    cleaned = cleaned.replaceAll(RegExp(r'\bpersonal record\b', caseSensitive: false), 'PR');
    cleaned = cleaned.replaceAll(RegExp(r'\bpersonal best\b', caseSensitive: false), 'PB');

    // EMOM
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:e\s*mom|every minute on the minute)\b', caseSensitive: false),
      'EMOM',
    );

    // Exercises acronyms
    cleaned = cleaned.replaceAll(RegExp(r'\br\s*d\s*l\b', caseSensitive: false), 'RDL');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bb\s*b\s*(bench|squat|deadlift|row|press)\b', caseSensitive: false),
      (m) => 'barbell ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bd\s*b\s*(bench|curl|press|fly|row)\b', caseSensitive: false),
      (m) => 'dumbbell ${m[1]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bk\s*b\s*(swing|squat|press|snatch)\b', caseSensitive: false),
      (m) => 'kettlebell ${m[1]}',
    );

    // Reps & sets syntax
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]+)\s*by\s*([0-9]+)\b', caseSensitive: false),
      (m) => '${m[1]}x${m[2]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]+)\s*sets\s*of\s*([0-9]+)\b', caseSensitive: false),
      (m) => '${m[1]}x${m[2]} reps',
    );

    // Weight units
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:kilos|kilo|kgs?)\b', caseSensitive: false),
      (m) => '${m[1]} kg',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:pounds|pound|lbs?)\b', caseSensitive: false),
      (m) => '${m[1]} lbs',
    );

    // 3. Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 4. Grammar and capitalization cleanup
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + (cleaned.length > 1 ? cleaned.substring(1) : '');
      cleaned = cleaned.replaceAll(RegExp(r'\bi\b'), 'I');
      cleaned = cleaned.replaceAll(RegExp(r"\bi'"), "I'");
      cleaned = cleaned.replaceAllMapped(
        RegExp(r'([\.\!\?]\s+)([a-z])'),
        (m) => '${m[1]}${m[2]!.toUpperCase()}',
      );
    }

    return cleaned;
  }
}
