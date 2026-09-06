import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:html/parser.dart';
import '../models/models.dart';
import '../services/exercise_service.dart';
import '../services/database_service.dart';
import '../providers/routine_provider.dart';
import 'memory/user_memory_service.dart';
import 'tools/gym_tools.dart';

class ToolResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  ToolResult({required this.success, required this.message, this.data});
}

class ToolExecutor {
  final RoutineProvider routineProvider;
  final ExerciseService exerciseService;
  final DatabaseService _db = DatabaseService();
  final UserMemoryService _memory = UserMemoryService();

  ToolExecutor({required this.routineProvider, ExerciseService? exerciseService})
      : exerciseService = exerciseService ?? ExerciseService();

  Future<ToolResult> execute(ToolCall call) async {
    switch (call.tool) {
      case 'create_routine':
        return _createRoutine(call.arguments);
      case 'search_exercises':
        return _searchExercises(call.arguments);
      case 'get_exercise_details':
        return _getExerciseDetails(call.arguments);
      case 'get_exercise_history':
        return _getExerciseHistory(call.arguments);
      case 'update_user_memory':
        return _updateUserMemory(call.arguments);
      case 'get_user_memory':
        return _getUserMemory();
      case 'generate_stick_animation':
        return _generateStickAnimation(call.arguments);
      case 'explain_exercise':
        return _explainExercise(call.arguments);
      case 'analyze_pose':
        return _analyzePose(call.arguments);
      case 'search_web':
        return _searchWeb(call.arguments);
      case 'lookup_food':
        return _lookupFood(call.arguments);
      default:
        return ToolResult(
            success: false, message: 'Unknown tool: ${call.tool}');
    }
  }

  Future<ToolResult> _updateUserMemory(Map<String, dynamic> args) async {
    final goal = args['goal']?.toString();

    List<String>? extractList(dynamic val) {
      if (val == null) return null;
      if (val is List) return val.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      if (val is String && val.trim().isNotEmpty) return [val.trim()];
      return null;
    }

    final addEq = extractList(args['add_equipment'] ?? args['equipment']);
    final remEq = extractList(args['remove_equipment']);
    final addInj = extractList(args['add_injuries'] ?? args['injuries'] ?? args['limitations']);
    final remInj = extractList(args['remove_injuries']);
    final addPref = extractList(args['add_preferences'] ?? args['preferences']);

    final profile = await _memory.updateMemory(
      goal: goal,
      addEquipment: addEq,
      removeEquipment: remEq,
      addInjuries: addInj,
      removeInjuries: remInj,
      addPreferences: addPref,
    );

    return ToolResult(
      success: true,
      message: 'Memory updated successfully:\n${profile.toContextPrompt()}',
      data: profile.toJson(),
    );
  }

  Future<ToolResult> _getUserMemory() async {
    final profile = await _memory.getProfile();
    return ToolResult(
      success: true,
      message: profile.isEmpty ? 'No memory saved yet.' : profile.toContextPrompt(),
      data: profile.toJson(),
    );
  }

  Future<ToolResult> _createRoutine(Map<String, dynamic> args) async {
    final name = args['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      return ToolResult(success: false, message: 'create_routine: missing name');
    }
    final exs = args['exercises'] as List?;
    if (exs == null || exs.isEmpty) {
      return ToolResult(success: false, message: 'create_routine: no exercises');
    }
    final routineExercises = <RoutineExercise>[];
    final invalid = <String>[];
    for (var i = 0; i < exs.length; i++) {
      final e = exs[i] as Map;
      final rawId = (e['exerciseId'] ?? e['exercise_id'] ?? e['id'] ?? e['name'] ?? '').toString().trim();
      if (rawId.isEmpty) continue;

      Exercise? ex = exerciseService.getById(rawId);
      ex ??= exerciseService.getByName(rawId);
      if (ex == null) {
        final cleanQuery = rawId.replaceAll('__', ' ').replaceAll('_', ' ').trim();
        final results = exerciseService.search(cleanQuery);
        if (results.isNotEmpty) {
          ex = results.first;
        }
      }

      if (ex == null) {
        invalid.add(rawId);
        continue;
      }
      routineExercises.add(RoutineExercise(
        exerciseId: ex.id,
        exerciseName: ex.name,
        order: i,
        targetSets: (e['targetSets'] ?? e['target_sets'] ?? 3) as int? ?? 3,
        targetReps: (e['targetReps'] ?? e['target_reps'] ?? 10) as int?,
        targetWeight: (e['targetWeight'] is num)
            ? (e['targetWeight'] as num).toDouble()
            : null,
      ));
    }
    if (routineExercises.isEmpty) {
      return ToolResult(
          success: false,
          message: 'No valid exerciseIds. Invalid: ${invalid.join(", ")}');
    }
    final routine = await routineProvider.createRoutine(
      name: name,
      description: args['goal']?.toString(),
      exercises: routineExercises,
    );
    if (routine == null) {
      return ToolResult(success: false, message: 'Failed to create routine (DB)');
    }
    return ToolResult(
      success: true,
      message: 'Routine "$name" created with ${routineExercises.length} exercises'
          '${invalid.isNotEmpty ? ' (skipped invalid: ${invalid.join(", ")})' : ''}',
      data: {'routineId': routine.id, 'name': routine.name},
    );
  }

  Future<ToolResult> _searchExercises(Map<String, dynamic> args) async {
    final query = args['query']?.toString() ?? '';
    final muscle = args['muscle']?.toString();
    final equipment = args['equipment']?.toString();
    final limit = (args['limit'] as num?)?.toInt() ?? 8;

    final results = exerciseService.search(
      query,
      muscle: muscle,
      equipment: equipment,
    );

    final top = results.take(limit).toList();
    if (top.isEmpty) {
      return ToolResult(
        success: true,
        message: 'No exercises found matching your filter criteria.',
        data: {'exercises': []},
      );
    }

    final formatted = top
        .map((e) => '• **${e.name}** (`${e.id}`) — ${e.primaryMuscle} | ${e.equipment}')
        .join('\n');

    return ToolResult(
      success: true,
      message: 'Found **${results.length}** exercises:\n\n$formatted',
      data: {
        'exercises': top
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'muscle': e.primaryMuscle,
                  'equipment': e.equipment,
                })
            .toList(),
        'total': results.length,
      },
    );
  }

  Exercise? _findExercise(String queryOrId) {
    final clean = queryOrId.trim();
    if (clean.isEmpty) return null;
    final direct = exerciseService.getById(clean);
    if (direct != null) return direct;
    final byName = exerciseService.getByName(clean);
    if (byName != null) return byName;
    final search = exerciseService.search(clean);
    if (search.isNotEmpty) return search.first;
    return null;
  }

  Future<ToolResult> _getExerciseDetails(Map<String, dynamic> args) async {
    final query = args['exerciseId']?.toString() ?? args['name']?.toString() ?? '';
    final ex = _findExercise(query);
    if (ex == null) {
      return ToolResult(
        success: false,
        message: 'Could not find an exercise matching "$query" in the library.',
      );
    }

    final buf = StringBuffer();
    buf.writeln('### ${ex.name}');
    buf.writeln('• **Primary Muscle:** ${ex.primaryMuscle}');
    if (ex.secondaryMuscles.isNotEmpty) {
      buf.writeln('• **Secondary Muscles:** ${ex.secondaryMuscles.join(", ")}');
    }
    buf.writeln('• **Equipment:** ${ex.equipment}');
    buf.writeln('• **ID:** `${ex.id}`');
    buf.writeln();

    if (ex.howToSteps.isNotEmpty) {
      buf.writeln('**How-To Execution Steps:**');
      for (int i = 0; i < ex.howToSteps.length; i++) {
        final step = ex.howToSteps[i];
        buf.writeln('${i + 1}. $step');
      }
    } else if (ex.howTo != null && ex.howTo!.trim().isNotEmpty) {
      buf.writeln('**How-To Execution:**\n${ex.howTo}');
    } else {
      buf.writeln('*(No step-by-step instructions logged for this exercise yet)*');
    }

    return ToolResult(
      success: true,
      message: buf.toString(),
      data: {
        'id': ex.id,
        'name': ex.name,
        'equipment': ex.equipment,
        'primaryMuscle': ex.primaryMuscle,
        'howTo': ex.howTo,
        'howToSteps': ex.howToSteps,
      },
    );
  }

  Future<ToolResult> _getExerciseHistory(Map<String, dynamic> args) async {
    final query = args['exerciseId']?.toString() ?? args['name']?.toString() ?? '';
    final ex = _findExercise(query);
    final lookupId = ex?.id ?? query;
    final displayName = ex?.name ?? query;

    final prs = await _db.getPersonalRecordsForExercise(lookupId);
    final rawLogs = await _db.getExerciseHistoryLogs(lookupId, limit: 10);

    if (prs.isEmpty && rawLogs.isEmpty) {
      return ToolResult(
        success: true,
        message: 'No recorded workout sets or personal records found for **$displayName** yet.',
        data: {'exerciseId': lookupId, 'hasHistory': false},
      );
    }

    final buf = StringBuffer();
    buf.writeln('### Workout History: $displayName');

    if (prs.isNotEmpty) {
      buf.writeln('**Personal Records (PRs):**');
      for (final pr in prs) {
        final valStr = pr.type == PRType.maxWeight
            ? '${pr.value} kg'
            : pr.type == PRType.maxReps
                ? '${pr.value.toInt()} reps'
                : '${pr.value}';
        final secStr = pr.secondaryValue != null && pr.secondaryValue! > 0
            ? ' (@ ${pr.secondaryValue} kg)'
            : '';
        buf.writeln('• ${_prTypeLabel(pr.type)}: **$valStr$secStr**');
      }
      buf.writeln();
    }

    if (rawLogs.isNotEmpty) {
      buf.writeln('**Recent Logged Workout Sessions:**');
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final log in rawLogs) {
        final key = '${log['workout_name'] ?? 'Workout'} | ${log['start_time']}';
        grouped.putIfAbsent(key, () => []).add(log);
      }

      int sessionCount = 0;
      for (final entry in grouped.entries) {
        if (sessionCount++ >= 4) break;
        final parts = entry.key.split(' | ');
        final wName = parts[0];
        final dateStr = parts.length > 1 ? parts[1].split('T')[0] : '';

        buf.writeln('**$wName** ($dateStr):');
        for (final s in entry.value) {
          final setNum = s['set_number'] ?? 1;
          final weight = s['weight'] != null ? '${s['weight']} kg' : null;
          final reps = s['reps'] != null ? '${s['reps']} reps' : null;
          final details = [?weight, ?reps].join(' × ');
          buf.writeln('  - Set $setNum: $details');
        }
      }
    }

    return ToolResult(
      success: true,
      message: buf.toString(),
      data: {'exerciseId': lookupId, 'hasHistory': true},
    );
  }

  String _prTypeLabel(PRType type) {
    switch (type) {
      case PRType.maxWeight:
        return 'Max Weight';
      case PRType.maxVolume:
        return 'Max Volume';
      case PRType.maxReps:
        return 'Max Reps';
      case PRType.maxRepsAtWeight:
        return 'Max Reps at Weight';
      case PRType.oneRepMax:
        return 'Estimated 1RM';
      case PRType.maxDuration:
        return 'Max Duration';
      case PRType.maxDistance:
        return 'Max Distance';
    }
  }

  Future<ToolResult> _generateStickAnimation(
      Map<String, dynamic> args) async {
    final exerciseId = args['exerciseId']?.toString() ?? '';
    final keyframes = args['keyframes'];
    // Persist to app docs so ExerciseDetailScreen can prefer it.
    try {
      final docs = await getApplicationSupportDirectory();
      final dir = Directory('${docs.path}/stick_keyframes');
      if (!await dir.exists()) await dir.create(recursive: true);
      final payload = {
        'exerciseId': exerciseId,
        'keyframes': keyframes ?? _defaultKeyframes(exerciseId),
        'generatedAt': DateTime.now().toIso8601String(),
      };
      final f = File('${dir.path}/$exerciseId.json');
      await f.writeAsString(jsonEncode(payload));
      return ToolResult(
        success: true,
        message: 'Stick animation saved for $exerciseId',
        data: {'path': f.path},
      );
    } catch (e) {
      return ToolResult(success: false, message: 'Failed to save keyframes: $e');
    }
  }

  Future<ToolResult> _explainExercise(Map<String, dynamic> args) async {
    final id = args['exerciseId']?.toString() ?? '';
    final ex = exerciseService.getById(id);
    if (ex == null) {
      return ToolResult(success: false, message: 'Unknown exerciseId $id');
    }
    final steps = ex.howToSteps.isNotEmpty
        ? ex.howToSteps.join('\n')
        : 'No how-to available.';
    return ToolResult(
      success: true,
      message: '${ex.name} — ${ex.primaryMuscle}\n$steps',
      data: {'exerciseId': ex.id, 'name': ex.name},
    );
  }

  Future<ToolResult> _analyzePose(Map<String, dynamic> args) async {
    // Placeholder - PoseContext injected by caller in Phase 2.
    return ToolResult(
        success: true,
        message: 'Pose analysis dummy: keep knees aligned, depth good.');
  }

  List<Map<String, dynamic>> _defaultKeyframes(String id) {
    // Two-pose lerp defaults (standing <-> squat) as safe fallback
    return [
      {
        't': 0.0,
        'joints': {
          'nose': [0.5, 0.15],
          'shoulder_l': [0.42, 0.30],
          'shoulder_r': [0.58, 0.30],
          'elbow_l': [0.38, 0.45],
          'elbow_r': [0.62, 0.45],
          'hip_l': [0.45, 0.55],
          'hip_r': [0.55, 0.55],
          'knee_l': [0.44, 0.78],
          'knee_r': [0.56, 0.78],
          'ankle_l': [0.43, 0.95],
          'ankle_r': [0.57, 0.95],
        }
      },
      {
        't': 1.0,
        'joints': {
          'nose': [0.5, 0.22],
          'shoulder_l': [0.42, 0.36],
          'shoulder_r': [0.58, 0.36],
          'elbow_l': [0.36, 0.52],
          'elbow_r': [0.64, 0.52],
          'hip_l': [0.43, 0.68],
          'hip_r': [0.57, 0.68],
          'knee_l': [0.42, 0.80],
          'knee_r': [0.58, 0.80],
          'ankle_l': [0.43, 0.95],
          'ankle_r': [0.57, 0.95],
        }
      }
    ];
  }

  Future<ToolResult> _searchWeb(Map<String, dynamic> args) async {
    final query = args['query']?.toString();
    if (query == null || query.isEmpty) {
      return ToolResult(success: false, message: 'search_web: missing query');
    }
    try {
      final uri = Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}');
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      
      final document = parse(body);
      final results = document.querySelectorAll('.result__snippet');
      final snippets = results.take(3).map((e) => e.text.trim()).join('\n\n');

      if (snippets.isEmpty) {
        return ToolResult(success: true, message: 'No clear results found for "$query".');
      }

      return ToolResult(
        success: true,
        message: 'Search Results for "$query":\n\n$snippets',
        data: {'snippets': snippets},
      );
    } catch (e) {
      return ToolResult(success: false, message: 'Failed to search web: $e');
    }
  }

  Future<ToolResult> _lookupFood(Map<String, dynamic> args) async {
    final query = args['query']?.toString().trim();
    if (query == null || query.isEmpty) {
      return ToolResult(success: false, message: 'lookup_food: missing query');
    }
    try {
      final client = HttpClient();
      final isBarcode = RegExp(r'^\d{8,14}$').hasMatch(query);
      final Uri uri;
      if (isBarcode) {
        uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$query.json');
      } else {
        uri = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}&search_simple=1&action=process&json=1&page_size=3');
      }

      final request = await client.getUrl(uri);
      request.headers.add('User-Agent', 'REPP-App/1.0 (fitness-app; Android)');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      Map<String, dynamic>? product;
      if (isBarcode) {
        if (data['status'] == 1 && data['product'] != null) {
          product = data['product'] as Map<String, dynamic>;
        }
      } else {
        final products = data['products'] as List?;
        if (products != null && products.isNotEmpty) {
          product = products.first as Map<String, dynamic>;
        }
      }

      if (product == null) {
        return ToolResult(
          success: true,
          message: 'No matching product found on Open Food Facts for "$query".',
        );
      }

      final name = product['product_name'] ?? product['generic_name'] ?? query;
      final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};
      final calories = (nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0).toInt();
      final protein = (nutriments['proteins_100g'] ?? nutriments['proteins'] ?? 0.0).toDouble();
      final carbs = (nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates'] ?? 0.0).toDouble();
      final fat = (nutriments['fat_100g'] ?? nutriments['fat'] ?? 0.0).toDouble();

      final summary = 'Product: $name\n(Per 100g):\n• Calories: $calories kcal\n• Protein: ${protein.toStringAsFixed(1)}g\n• Carbs: ${carbs.toStringAsFixed(1)}g\n• Fat: ${fat.toStringAsFixed(1)}g';

      return ToolResult(
        success: true,
        message: summary,
        data: {
          'food_name': name,
          'calories': calories,
          'protein_g': protein,
          'carbs_g': carbs,
          'fat_g': fat,
        },
      );
    } catch (e) {
      return ToolResult(success: false, message: 'Open Food Facts lookup failed: $e');
    }
  }
}
