import 'dart:convert';

/// Tool definitions exposed to the LLM.
/// JSON schema kept Dart-native so UI + agent share single source.
class GymTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final List<String> required;

  const GymTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.required,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': parameters,
          'required': required,
        }
      };
}

class GymTools {
  static const createRoutine = GymTool(
    name: 'create_routine',
    description:
        'Create a workout routine from a plan. exerciseIds must be existing IDs from ExerciseService.',
    parameters: {
      'name': {'type': 'string', 'description': 'Routine name, e.g. Push Day A'},
      'goal': {
        'type': 'string',
        'enum': ['strength', 'hypertrophy', 'endurance', 'fat_loss']
      },
      'days_per_week': {'type': 'integer'},
      'exercises': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'exerciseId': {'type': 'string'},
            'targetSets': {'type': 'integer'},
            'targetReps': {'type': 'integer'},
            'targetWeight': {'type': 'number'},
          },
          'required': ['exerciseId', 'targetSets', 'targetReps']
        }
      }
    },
    required: ['name', 'exercises'],
  );

  static const searchExercises = GymTool(
    name: 'search_exercises',
    description:
        'Search or filter the exercise database by keywords, target muscle, or equipment.',
    parameters: {
      'query': {
        'type': 'string',
        'description': 'Keyword search in exercise name (e.g. "press", "squat", "curl")'
      },
      'muscle': {
        'type': 'string',
        'description': 'Target muscle (e.g. "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quadriceps", "Hamstrings", "Glutes", "Abs")'
      },
      'equipment': {
        'type': 'string',
        'description': 'Equipment type (e.g. "Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell", "None")'
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum number of results to return (default 8)'
      }
    },
    required: [],
  );

  static const generateStickAnimation = GymTool(
    name: 'generate_stick_animation',
    description:
        'Generate stick-figure keyframes for an exercise. Joints are normalized 0..1 in a 1x1 canvas. Use 2-4 keyframes lerp.',
    parameters: {
      'exerciseId': {'type': 'string'},
      'keyframes': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            't': {'type': 'number'},
            'joints': {'type': 'object'}
          }
        }
      }
    },
    required: ['exerciseId'],
  );

  static const getExerciseDetails = GymTool(
    name: 'get_exercise_details',
    description:
        'Get full details for an exercise, including step-by-step How-To instructions, technique guide, target muscles, and equipment.',
    parameters: {
      'exerciseId': {
        'type': 'string',
        'description': 'Exercise ID or name (e.g. "bench_press__barbell_", "squat", "pull_up")'
      }
    },
    required: ['exerciseId'],
  );

  static const getExerciseHistory = GymTool(
    name: 'get_exercise_history',
    description:
        'Query the user\'s personal workout history, past sets, logged weights/reps, and personal records (PRs) for an exercise.',
    parameters: {
      'exerciseId': {
        'type': 'string',
        'description': 'Exercise ID or name (e.g. "bench_press__barbell_", "squat", "deadlift")'
      },
      'limit': {
        'type': 'integer',
        'description': 'Max past workouts to retrieve (default 5)'
      }
    },
    required: ['exerciseId'],
  );

  static const explainExercise = GymTool(
    name: 'explain_exercise',
    description: 'Return structured explanation + how-to for an exerciseId.',
    parameters: {
      'exerciseId': {'type': 'string'},
    },
    required: ['exerciseId'],
  );

  static const searchWeb = GymTool(
    name: 'search_web',
    description: 'Search the internet for up-to-date fitness, nutrition, or general knowledge using DuckDuckGo.',
    parameters: {
      'query': {
        'type': 'string',
        'description': 'Search query to look up on the internet',
      }
    },
    required: ['query'],
  );

  static const lookupFood = GymTool(
    name: 'lookup_food',
    description: 'Search Open Food Facts for packaged foods, barcode, or ingredients to get exact calories, protein, carbs, and fat.',
    parameters: {
      'query': {
        'type': 'string',
        'description': 'Product name, brand, or barcode (e.g. "Oats", "Greek Yogurt", "3017620422003")',
      }
    },
    required: ['query'],
  );

  static const analyzePose = GymTool(
    name: 'analyze_pose',
    description:
        'Analyze current PoseContext and return form cues. Input is auto-filled from camera.',
    parameters: {
      'exercise_hint': {'type': 'string'}
    },
    required: [],
  );

  static const updateUserMemory = GymTool(
    name: 'update_user_memory',
    description:
        'Save or update the user\'s fitness profile, workout goals, available equipment, injuries, limitations, or preferences into persistent local memory.',
    parameters: {
      'goal': {
        'type': 'string',
        'description': 'Primary workout goal (e.g. "hypertrophy", "strength", "fat loss")'
      },
      'add_equipment': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Equipment available to user (e.g. ["Dumbbells", "Pull-up bar"])'
      },
      'remove_equipment': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Equipment no longer available'
      },
      'add_injuries': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Injuries, joint pains, or physical limitations (e.g. ["left rotator cuff pain", "bad lower back"])'
      },
      'remove_injuries': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Healed injuries or limitations to remove'
      },
      'add_preferences': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Workout preferences (e.g. ["prefers 45-minute workouts", "likes supersets"])'
      },
    },
    required: [],
  );

  static const getUserMemory = GymTool(
    name: 'get_user_memory',
    description: 'Read the user\'s currently saved profile, goals, equipment, and injuries.',
    parameters: {},
    required: [],
  );

  static List<GymTool> get all => [
        createRoutine,
        searchExercises,
        getExerciseDetails,
        getExerciseHistory,
        updateUserMemory,
        getUserMemory,
        explainExercise,
        generateStickAnimation,
        analyzePose,
      ];

  static List<Map<String, dynamic>> get allJson =>
      all.map((t) => t.toJson()).toList();
}

/// Parsed tool call from LLM text (```json {tool:...}``` or raw json).
class ToolCall {
  final String tool;
  final Map<String, dynamic> arguments;
  final String raw;

  ToolCall({required this.tool, required this.arguments, required this.raw});

  static ToolCall? tryParse(String llmOutput) {
    final text = llmOutput.trim();

    // 1. Check for ChatML / Python style tool call:
    // E.g. <|tool_call_start|>[create_routine(...)]<|tool_call_end|> or [create_routine(...)]
    final chatMlMatch = RegExp(r'<\|tool_call_start\|>\s*(\[?[a-zA-Z0-9_]+\([\s\S]*?\)?\]?)\s*<\|tool_call_end\|>').firstMatch(text);
    if (chatMlMatch != null) {
      final parsed = _parsePythonCall(chatMlMatch.group(1)!);
      if (parsed != null) return parsed;
    }

    final bracketCallMatch = RegExp(r'\[([a-zA-Z0-9_]+)\(([\s\S]*?)\)\]').firstMatch(text);
    if (bracketCallMatch != null) {
      final parsed = _parsePythonCall(bracketCallMatch.group(0)!);
      if (parsed != null) return parsed;
    }

    // 2. Prefer fenced JSON block (```json or ```)
    final fenced = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    final candidate =
        fenced != null ? fenced.group(1)!.trim() : _extractJsonObject(text);
    if (candidate == null) return null;
    try {
      final map = jsonDecode(candidate) as Map<String, dynamic>;
      final tool = (map['tool'] ?? map['name'] ?? map['action'])?.toString();
      final args = map['arguments'] ?? map['args'] ?? map['parameters'];
      
      if (tool != null && args is Map) {
        return ToolCall(
          tool: tool,
          arguments: args.cast<String, dynamic>(),
          raw: candidate,
        );
      }

      // Check if candidate is directly {"create_routine": {...}}
      if (map.containsKey('create_routine') && map['create_routine'] is Map) {
        return ToolCall(
          tool: 'create_routine',
          arguments: (map['create_routine'] as Map).cast<String, dynamic>(),
          raw: candidate,
        );
      }

      // Check if candidate is directly a routine object with "name" and "exercises"
      if (map.containsKey('exercises') &&
          (map.containsKey('name') || map.containsKey('routine_name') || map.containsKey('title'))) {
        return ToolCall(
          tool: 'create_routine',
          arguments: map,
          raw: candidate,
        );
      }

      if (tool != null) {
        return ToolCall(
          tool: tool,
          arguments: {},
          raw: candidate,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Removes any tool JSON blocks (fenced or raw) and ChatML tags from the assistant's conversational text
  static String stripToolCall(String text) {
    var cleaned = text;
    // Strip ChatML tool tags
    cleaned = cleaned.replaceAll(RegExp(r'<\|tool_call_start\|>[\s\S]*?<\|tool_call_end\|>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[[a-zA-Z0-9_]+\([\s\S]*?\)\]'), '');
    // Strip fenced code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?\s*\{[\s\S]*?\}\s*```'), '');
    final rawObj = _extractJsonObject(cleaned);
    if (rawObj != null) {
      cleaned = cleaned.replaceFirst(rawObj, '');
    }
    return cleaned.trim();
  }

  static ToolCall? _parsePythonCall(String rawText) {
    final match = RegExp(r'\[?\s*([a-zA-Z0-9_]+)\s*\(([\s\S]*?)\)\s*\]?').firstMatch(rawText);
    if (match == null) return null;
    final tool = match.group(1);
    final rawArgs = match.group(2)?.trim() ?? '';
    if (tool == null || tool.isEmpty) return null;

    final args = _parseKwargs(rawArgs);
    return ToolCall(
      tool: tool,
      arguments: args,
      raw: match.group(0) ?? rawText,
    );
  }

  static Map<String, dynamic> _parseKwargs(String s) {
    final result = <String, dynamic>{};
    int i = 0;
    while (i < s.length) {
      while (i < s.length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r' || s[i] == ',')) {
        i++;
      }
      if (i >= s.length) break;

      final keyStart = i;
      while (i < s.length && (RegExp(r'[a-zA-Z0-9_]').hasMatch(s[i]))) {
        i++;
      }
      final key = s.substring(keyStart, i).trim();
      if (key.isEmpty) break;

      while (i < s.length && s[i] != '=') {
        i++;
      }
      if (i < s.length && s[i] == '=') i++;

      while (i < s.length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) {
        i++;
      }
      if (i >= s.length) break;

      final valStart = i;
      if (s[i] == '"' || s[i] == "'") {
        final quote = s[i];
        i++;
        final strBuf = StringBuffer();
        while (i < s.length && s[i] != quote) {
          if (s[i] == '\\' && i + 1 < s.length) {
            strBuf.write(s[i + 1]);
            i += 2;
          } else {
            strBuf.write(s[i]);
            i++;
          }
        }
        if (i < s.length) i++;
        result[key] = strBuf.toString();
      } else if (s[i] == '[' || s[i] == '{') {
        final open = s[i];
        final close = open == '[' ? ']' : '}';
        int depth = 0;
        bool inStr = false;
        String strQuote = '';
        while (i < s.length) {
          final c = s[i];
          if (inStr) {
            if (c == strQuote && s[i - 1] != '\\') {
              inStr = false;
            }
          } else {
            if (c == '"' || c == "'") {
              inStr = true;
              strQuote = c;
            } else if (c == open) {
              depth++;
            } else if (c == close) {
              depth--;
              if (depth == 0) {
                i++;
                break;
              }
            }
          }
          i++;
        }
        final rawSub = s.substring(valStart, i);
        result[key] = _pythonLiteralToJson(rawSub);
      } else {
        while (i < s.length && s[i] != ',' && s[i] != ')') {
          i++;
        }
        final rawSub = s.substring(valStart, i).trim();
        if (rawSub.toLowerCase() == 'true') {
          result[key] = true;
        } else if (rawSub.toLowerCase() == 'false') {
          result[key] = false;
        } else if (rawSub.toLowerCase() == 'none' || rawSub.toLowerCase() == 'null') {
          result[key] = null;
        } else if (int.tryParse(rawSub) != null) {
          result[key] = int.parse(rawSub);
        } else if (double.tryParse(rawSub) != null) {
          result[key] = double.parse(rawSub);
        } else {
          result[key] = rawSub;
        }
      }
    }
    return result;
  }

  static dynamic _pythonLiteralToJson(String raw) {
    var formatted = raw
        .replaceAll(RegExp(r'\bTrue\b'), 'true')
        .replaceAll(RegExp(r'\bFalse\b'), 'false')
        .replaceAll(RegExp(r'\bNone\b'), 'null');
    formatted = formatted.replaceAllMapped(
      RegExp(r"(?<!\\)'(.*?[^\\])?'"),
      (match) {
        final inside = match.group(1) ?? '';
        final escaped = inside.replaceAll('"', '\\"');
        return '"$escaped"';
      },
    );
    try {
      return jsonDecode(formatted);
    } catch (_) {
      return raw;
    }
  }

  static String? _extractJsonObject(String s) {
    // Match any JSON opening with "tool", "name", "action", "create_routine", or "exercises"
    final pattern = RegExp(r'\{\s*"(?:tool|name|action|create_routine|exercises)"\s*:');
    final match = pattern.firstMatch(s);
    if (match == null) return null;
    return _balanced(s, match.start);
  }

  static String? _balanced(String s, int start) {
    int depth = 0;
    for (var i = start; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }
}
