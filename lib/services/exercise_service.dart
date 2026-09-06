import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'database_service.dart';

class ExerciseService {
  static final ExerciseService _instance = ExerciseService._internal();
  final DatabaseService _db = DatabaseService();

  List<Exercise> _exercises = [];
  List<Exercise> _customExercises = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  factory ExerciseService() => _instance;

  ExerciseService._internal();

  /// Get all exercises (built-in + custom)
  List<Exercise> get exercises => [..._exercises, ..._customExercises];

  /// Check if exercises are loaded
  bool get isLoaded => _isLoaded;

  /// Get exercise count
  int get exerciseCount => _exercises.length + _customExercises.length;

  /// Load exercises from CSV and database
  Future<void> loadExercises() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;

    // Load built-in exercises from CSV
    await _loadFromCsv();

    // Load custom exercises from database
    await _loadCustomExercises();

    _isLoaded = true;
    _isLoading = false;

    debugPrint('ExerciseService: Loaded ${_exercises.length} exercises from CSV');
  }

  /// Reload exercises (useful after adding custom exercises)
  Future<void> reload() async {
    _isLoaded = false;
    _isLoading = false;
    await loadExercises();
  }

  /// Load exercises from bundled CSV file
  Future<void> _loadFromCsv() async {
    try {
      String csvString = await rootBundle.loadString(
        'assets/data/exercises.csv',
      );

      debugPrint('ExerciseService: CSV string length: ${csvString.length}');

      // Normalize line endings to \n
      csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Split by lines and parse manually for better control
      final lines = csvString.split('\n');
      debugPrint('ExerciseService: CSV has ${lines.length} lines');

      if (lines.isEmpty) {
        debugPrint('ExerciseService: CSV is empty');
        return;
      }

      // Skip header row, parse each line
      _exercises = [];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final fields = _parseCSVLine(line);
          if (fields.length >= 4) {
            // Get video and thumbnail URLs
            final videoUrl =
                fields.length > 4 && fields[4] != 'None' && fields[4].isNotEmpty
                ? fields[4]
                : null;
            final thumbnailUrl =
                fields.length > 5 && fields[5] != 'None' && fields[5].isNotEmpty
                ? fields[5]
                : null;
            final howTo =
                fields.length > 6 &&
                    fields[6] != 'None' &&
                    fields[6].trim().isNotEmpty
                ? fields[6].trim()
                : null;

            final exercise = Exercise(
              id: fields[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
              name: fields[0],
              equipment: fields.length > 1 ? fields[1] : 'None',
              primaryMuscle: fields.length > 2
                  ? _formatMuscleName(fields[2])
                  : 'Other',
              secondaryMuscles: fields.length > 3 && fields[3] != 'None'
                  ? fields[3]
                        .split(',')
                        .map((s) => _formatMuscleName(s.trim()))
                        .where((s) => s.isNotEmpty)
                        .toList()
                  : [],
              videoUrl: videoUrl,
              thumbnailUrl: thumbnailUrl,
              howTo: howTo,
              isCustom: false,
            );
            if (exercise.name.isNotEmpty) {
              _exercises.add(exercise);
            }
          }
        } catch (e) {
          debugPrint('ExerciseService: Error parsing line $i: $e');
        }
      }

      // Sort by name
      _exercises.sort((a, b) => a.name.compareTo(b.name));

      // Deduplicate exercises - prefer ones with more data (thumbnails, videos)
      _exercises = _deduplicateExercises(_exercises);

      debugPrint(
        'ExerciseService: Successfully parsed ${_exercises.length} exercises (after deduplication)',
      );

      // Print a few examples and howTo stats
      if (_exercises.isNotEmpty) {
        debugPrint('ExerciseService: First exercise: ${_exercises[0].name}');
        debugPrint(
          'ExerciseService: Last exercise: ${_exercises[_exercises.length - 1].name}',
        );
        final withHowTo = _exercises
            .where((e) => e.howTo != null && e.howTo!.isNotEmpty)
            .length;
        debugPrint(
          'ExerciseService: Exercises with howTo: $withHowTo / ${_exercises.length}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('ExerciseService: Error loading exercises from CSV: $e');
      debugPrint('Stack trace: $stackTrace');
      _exercises = [];
    }
  }

  /// Format muscle name: replace underscores with spaces and capitalize words
  String _formatMuscleName(String muscle) {
    if (muscle.isEmpty || muscle == 'None') return muscle;

    // Replace underscores with spaces
    String formatted = muscle.replaceAll('_', ' ');

    // Capitalize first letter of each word
    formatted = formatted
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');

    return formatted;
  }

  /// Deduplicate exercises by name, preferring entries with better data
  List<Exercise> _deduplicateExercises(List<Exercise> exercises) {
    final Map<String, Exercise> uniqueExercises = {};

    for (final exercise in exercises) {
      final nameLower = exercise.name.toLowerCase().trim();

      if (uniqueExercises.containsKey(nameLower)) {
        // Compare and keep the one with better data
        final existing = uniqueExercises[nameLower]!;
        final existingScore = _exerciseDataScore(existing);
        final newScore = _exerciseDataScore(exercise);

        if (newScore > existingScore) {
          uniqueExercises[nameLower] = exercise;
        }
      } else {
        uniqueExercises[nameLower] = exercise;
      }
    }

    return uniqueExercises.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Score an exercise based on data quality
  /// Uses Hevy (CloudFront) data only
  int _exerciseDataScore(Exercise exercise) {
    int score = 0;

    // Check for Hevy/CloudFront URLs (better curated data)
    final isHevyData =
        exercise.thumbnailUrl?.contains('cloudfront.net') == true ||
        exercise.videoUrl?.contains('cloudfront.net') == true;

    if (isHevyData) {
      score += 100; // Hevy data
    }

    // Has thumbnail
    if (exercise.thumbnailUrl != null &&
        exercise.thumbnailUrl!.isNotEmpty &&
        exercise.thumbnailUrl != 'None') {
      score += 5;
    }

    // Has video
    if (exercise.videoUrl != null &&
        exercise.videoUrl!.isNotEmpty &&
        exercise.videoUrl != 'None') {
      score += 5;
    }

    // Prefer simple/common muscle names
    final simpleMusclenames = [
      'Chest',
      'Back',
      'Shoulders',
      'Biceps',
      'Triceps',
      'Forearms',
      'Abdominals',
      'Quadriceps',
      'Hamstrings',
      'Glutes',
      'Calves',
      'Cardio',
      'Full Body',
      'Upper Back',
      'Lower Back',
      'Lats',
      'Other',
      'None',
    ];

    if (simpleMusclenames.contains(exercise.primaryMuscle)) {
      score += 50; // Strongly prefer simple/common muscle names
    }

    // Prefer standard equipment names
    final standardEquipment = [
      'None',
      'Barbell',
      'Dumbbell',
      'Machine',
      'Cable',
      'Kettlebell',
      'Resistance Band',
      'Suspension',
      'Other',
    ];

    if (standardEquipment.contains(exercise.equipment)) {
      score += 20;
    }

    // Has howTo instructions
    if (exercise.howTo != null && exercise.howTo!.isNotEmpty) {
      score += 30;
    }

    return score;
  }

  /// Parse a single CSV line handling quoted fields
  List<String> _parseCSVLine(String line) {
    List<String> fields = [];
    bool inQuotes = false;
    StringBuffer currentField = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        // Check for escaped quote
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField.toString().trim());
        currentField = StringBuffer();
      } else {
        currentField.write(char);
      }
    }

    // Add the last field
    fields.add(currentField.toString().trim());

    return fields;
  }

  /// Load custom exercises from database
  Future<void> _loadCustomExercises() async {
    try {
      _customExercises = await _db.getCustomExercises();
      _customExercises.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('ExerciseService: Error loading custom exercises: $e');
      _customExercises = [];
    }
  }

  /// Search exercises by query string
  /// Matches if ANY word in the query matches ANY word in the exercise name
  List<Exercise> search(String query, {String? equipment, String? muscle}) {
    // If not loaded, return empty but also try to load
    if (!_isLoaded) {
      debugPrint('ExerciseService: Not loaded yet, returning empty results');
      return [];
    }

    var results = exercises;

    // Filter by equipment if specified
    if (equipment != null &&
        equipment.isNotEmpty &&
        equipment != 'All Equipment') {
      results = results.where((e) => e.equipment == equipment).toList();
    }

    // Filter by muscle group if specified
    if (muscle != null && muscle.isNotEmpty && muscle != 'All Muscles') {
      results = results.where((e) {
        return e.primaryMuscle == muscle || e.secondaryMuscles.contains(muscle);
      }).toList();
    }

    // Search by query if provided
    if (query.trim().isNotEmpty) {
      final queryLower = query.toLowerCase().trim();
      final queryWords = queryLower
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      results = results.where((exercise) {
        return _matchesQuery(exercise, queryLower, queryWords);
      }).toList();

      // Sort by relevance
      results.sort((a, b) {
        final aScore = _searchScore(a, queryLower, queryWords);
        final bScore = _searchScore(b, queryLower, queryWords);
        return bScore.compareTo(aScore); // Higher score first
      });
    }

    return results;
  }

  /// Check if an exercise matches the search query
  /// Returns true if ANY query word matches ANY word in the exercise
  bool _matchesQuery(
    Exercise exercise,
    String queryLower,
    List<String> queryWords,
  ) {
    final nameLower = exercise.name.toLowerCase();
    final nameWords = nameLower
        .split(RegExp(r'[\s\-\(\)]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final equipmentLower = exercise.equipment.toLowerCase();
    final muscleLower = exercise.primaryMuscle.toLowerCase();

    // Check if the full query is contained anywhere
    if (nameLower.contains(queryLower)) return true;
    if (equipmentLower.contains(queryLower)) return true;
    if (muscleLower.contains(queryLower)) return true;

    // Check if ANY query word matches ANY part of the exercise
    for (final queryWord in queryWords) {
      // Check if query word is contained in name
      if (nameLower.contains(queryWord)) return true;

      // Check if query word matches start of any name word
      for (final nameWord in nameWords) {
        if (nameWord.startsWith(queryWord)) return true;
        // Also check if name word contains query word (partial match)
        if (nameWord.contains(queryWord)) return true;
      }

      // Check equipment and muscle
      if (equipmentLower.contains(queryWord)) return true;
      if (muscleLower.contains(queryWord)) return true;

      // Check secondary muscles
      for (final secondaryMuscle in exercise.secondaryMuscles) {
        if (secondaryMuscle.toLowerCase().contains(queryWord)) return true;
      }
    }

    return false;
  }

  /// Calculate search relevance score
  int _searchScore(
    Exercise exercise,
    String queryLower,
    List<String> queryWords,
  ) {
    int score = 0;
    final nameLower = exercise.name.toLowerCase();
    final nameWords = nameLower
        .split(RegExp(r'[\s\-\(\)]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Exact match with full query (highest priority)
    if (nameLower == queryLower) {
      score += 1000;
    }
    // Name starts with full query
    else if (nameLower.startsWith(queryLower)) {
      score += 500;
    }
    // Name contains full query
    else if (nameLower.contains(queryLower)) {
      score += 300;
    }

    // Score individual word matches
    for (final queryWord in queryWords) {
      // Exact word match
      if (nameWords.contains(queryWord)) {
        score += 100;
      }
      // Word starts with query word
      else if (nameWords.any((w) => w.startsWith(queryWord))) {
        score += 80;
      }
      // Word contains query word
      else if (nameWords.any((w) => w.contains(queryWord))) {
        score += 50;
      }
      // Name contains query word anywhere
      else if (nameLower.contains(queryWord)) {
        score += 30;
      }

      // Bonus for equipment match
      if (exercise.equipment.toLowerCase().contains(queryWord)) {
        score += 20;
      }

      // Bonus for primary muscle match
      if (exercise.primaryMuscle.toLowerCase().contains(queryWord)) {
        score += 25;
      }

      // Bonus for secondary muscle match
      for (final muscle in exercise.secondaryMuscles) {
        if (muscle.toLowerCase().contains(queryWord)) {
          score += 10;
        }
      }
    }

    // Penalize longer names (prefer more specific matches)
    score -= (nameLower.length ~/ 10);

    return score;
  }

  /// Get exercises filtered by muscle group
  List<Exercise> getByMuscle(String muscle) {
    if (!_isLoaded) return [];
    return exercises.where((e) {
      return e.primaryMuscle == muscle || e.secondaryMuscles.contains(muscle);
    }).toList();
  }

  /// Get exercises filtered by equipment
  List<Exercise> getByEquipment(String equipment) {
    if (!_isLoaded) return [];
    return exercises.where((e) => e.equipment == equipment).toList();
  }

  /// Get exercise by ID
  Exercise? getById(String id) {
    if (!_isLoaded) return null;
    try {
      return exercises.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get exercise by name
  Exercise? getByName(String name) {
    if (!_isLoaded) return null;
    try {
      return exercises.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all unique equipment types
  List<String> getEquipmentTypes() {
    if (!_isLoaded) return ['All Equipment'];
    final equipmentSet = exercises.map((e) => e.equipment).toSet();
    final list = equipmentSet.toList()..sort();
    return ['All Equipment', ...list];
  }

  /// Get all unique muscle groups
  List<String> getMuscleGroups() {
    if (!_isLoaded) return [];
    final muscleSet = <String>{};
    for (final exercise in exercises) {
      muscleSet.add(exercise.primaryMuscle);
      muscleSet.addAll(exercise.secondaryMuscles);
    }
    final list = muscleSet.toList()..sort();
    return list;
  }

  /// Get primary muscle groups (for filtering)
  List<String> getPrimaryMuscleGroups() {
    if (!_isLoaded) return [];
    final muscleSet = exercises.map((e) => e.primaryMuscle).toSet();
    final list = muscleSet.toList()..sort();
    return list;
  }

  /// Add a custom exercise
  Future<Exercise> addCustomExercise({
    required String name,
    required String equipment,
    required String primaryMuscle,
    List<String> secondaryMuscles = const [],
    String? notes,
  }) async {
    final exercise = Exercise(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      equipment: equipment,
      primaryMuscle: primaryMuscle,
      secondaryMuscles: secondaryMuscles,
      isCustom: true,
    );

    await _db.insertCustomExercise(exercise);
    _customExercises.add(exercise);
    _customExercises.sort((a, b) => a.name.compareTo(b.name));

    return exercise;
  }

  /// Delete a custom exercise
  Future<void> deleteCustomExercise(String id) async {
    await _db.deleteCustomExercise(id);
    _customExercises.removeWhere((e) => e.id == id);
  }

  /// Check if an exercise is custom
  bool isCustomExercise(String id) {
    return _customExercises.any((e) => e.id == id);
  }

  /// Get recently used exercises (based on workout history)
  Future<List<Exercise>> getRecentExercises({int limit = 10}) async {
    // This would query workout history - for now return empty
    // Full implementation would join with workout_exercises table
    return [];
  }

  /// Get popular exercises (most used)
  Future<List<Exercise>> getPopularExercises({int limit = 10}) async {
    // This would query workout history - for now return empty
    // Full implementation would count usage from workout_exercises table
    return [];
  }
}
