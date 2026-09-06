import 'package:uuid/uuid.dart';

/// Represents a single set within an exercise
class WorkoutSet {
  final String id;
  final int setNumber;
  final double? weight; // in kg or lbs based on user preference
  final int? reps;
  final double? duration; // in seconds, for timed exercises
  final double? distance; // in meters, for cardio
  final bool isWarmup;
  final bool isDropSet;
  final bool isFailure;
  final bool isCompleted;
  final String? notes;
  final DateTime? completedAt;

  WorkoutSet({
    String? id,
    required this.setNumber,
    this.weight,
    this.reps,
    this.duration,
    this.distance,
    this.isWarmup = false,
    this.isDropSet = false,
    this.isFailure = false,
    this.isCompleted = false,
    this.notes,
    this.completedAt,
  }) : id = id ?? const Uuid().v4();

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'] as String,
      setNumber: map['set_number'] as int,
      weight: map['weight'] as double?,
      reps: map['reps'] as int?,
      duration: map['duration'] as double?,
      distance: map['distance'] as double?,
      isWarmup: (map['is_warmup'] as int?) == 1,
      isDropSet: (map['is_drop_set'] as int?) == 1,
      isFailure: (map['is_failure'] as int?) == 1,
      isCompleted: (map['is_completed'] as int?) == 1,
      notes: map['notes'] as String?,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap(String workoutExerciseId) {
    return {
      'id': id,
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'duration': duration,
      'distance': distance,
      'is_warmup': isWarmup ? 1 : 0,
      'is_drop_set': isDropSet ? 1 : 0,
      'is_failure': isFailure ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  WorkoutSet copyWith({
    String? id,
    int? setNumber,
    double? weight,
    int? reps,
    double? duration,
    double? distance,
    bool? isWarmup,
    bool? isDropSet,
    bool? isFailure,
    bool? isCompleted,
    String? notes,
    DateTime? completedAt,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      isWarmup: isWarmup ?? this.isWarmup,
      isDropSet: isDropSet ?? this.isDropSet,
      isFailure: isFailure ?? this.isFailure,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Calculate volume for this set (weight * reps)
  double get volume => (weight ?? 0) * (reps ?? 0);

  /// Format display string for the set
  String get displayString {
    if (duration != null) {
      return '${duration!.toStringAsFixed(0)}s';
    }
    if (distance != null) {
      return '${(distance! / 1000).toStringAsFixed(2)} km';
    }
    if (weight != null && reps != null) {
      return '${weight!.toStringAsFixed(1)} × $reps';
    }
    if (reps != null) {
      return '$reps reps';
    }
    return '-';
  }

  @override
  String toString() {
    return 'WorkoutSet(id: $id, setNumber: $setNumber, weight: $weight, '
        'reps: $reps, isCompleted: $isCompleted)';
  }
}

/// Represents an exercise within a workout with its sets
class WorkoutExercise {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int order;
  final List<WorkoutSet> sets;
  final String? notes;
  final String? supersetId; // Group exercises in superset

  WorkoutExercise({
    String? id,
    required this.exerciseId,
    required this.exerciseName,
    required this.order,
    List<WorkoutSet>? sets,
    this.notes,
    this.supersetId,
  }) : id = id ?? const Uuid().v4(),
       sets = sets ?? [];

  factory WorkoutExercise.fromMap(
    Map<String, dynamic> map,
    List<WorkoutSet> sets,
  ) {
    return WorkoutExercise(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      exerciseName: map['exercise_name'] as String,
      order: map['exercise_order'] as int,
      sets: sets,
      notes: map['notes'] as String?,
      supersetId: map['superset_id'] as String?,
    );
  }

  Map<String, dynamic> toMap(String workoutId) {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'exercise_order': order,
      'notes': notes,
      'superset_id': supersetId,
    };
  }

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    int? order,
    List<WorkoutSet>? sets,
    String? notes,
    String? supersetId,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      order: order ?? this.order,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      supersetId: supersetId ?? this.supersetId,
    );
  }

  /// Get total volume for this exercise
  double get totalVolume {
    return sets.fold(0, (sum, set) => sum + set.volume);
  }

  /// Get number of completed sets
  int get completedSets {
    return sets.where((s) => s.isCompleted).length;
  }

  /// Check if all sets are completed
  bool get isCompleted => sets.isNotEmpty && completedSets == sets.length;

  /// Get best set (highest volume)
  WorkoutSet? get bestSet {
    if (sets.isEmpty) return null;
    return sets.reduce((a, b) => a.volume > b.volume ? a : b);
  }

  @override
  String toString() {
    return 'WorkoutExercise(id: $id, exerciseName: $exerciseName, '
        'sets: ${sets.length}, order: $order)';
  }
}

/// Represents a complete workout session
class Workout {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<WorkoutExercise> exercises;
  final String? notes;
  final String? routineId; // If started from a routine
  final bool isTemplate; // If this is a routine template
  final int pausedSeconds; // Accumulated paused/dead idle time in seconds

  Workout({
    String? id,
    required this.name,
    DateTime? startTime,
    this.endTime,
    List<WorkoutExercise>? exercises,
    this.notes,
    this.routineId,
    this.isTemplate = false,
    this.pausedSeconds = 0,
  }) : id = id ?? const Uuid().v4(),
       startTime = startTime ?? DateTime.now(),
       exercises = exercises ?? [];

  factory Workout.fromMap(
    Map<String, dynamic> map,
    List<WorkoutExercise> exercises,
  ) {
    return Workout(
      id: map['id'] as String,
      name: map['name'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      exercises: exercises,
      notes: map['notes'] as String?,
      routineId: map['routine_id'] as String?,
      isTemplate: (map['is_template'] as int?) == 1,
      pausedSeconds: (map['paused_seconds'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'notes': notes,
      'routine_id': routineId,
      'is_template': isTemplate ? 1 : 0,
      'paused_seconds': pausedSeconds,
    };
  }

  Workout copyWith({
    String? id,
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    List<WorkoutExercise>? exercises,
    String? notes,
    String? routineId,
    bool? isTemplate,
    int? pausedSeconds,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
      routineId: routineId ?? this.routineId,
      isTemplate: isTemplate ?? this.isTemplate,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }

  /// Get workout duration (excluding accumulated paused/dead time)
  Duration? get duration {
    if (endTime == null) return null;
    final total = endTime!.difference(startTime);
    final activeSeconds = total.inSeconds - pausedSeconds;
    return Duration(seconds: activeSeconds > 0 ? activeSeconds : 0);
  }

  /// Get formatted duration string
  String get durationString {
    final dur = duration;
    if (dur == null) {
      final total = DateTime.now().difference(startTime);
      final activeSeconds = total.inSeconds - pausedSeconds;
      final elapsed = Duration(seconds: activeSeconds > 0 ? activeSeconds : 0);
      return _formatDuration(elapsed);
    }
    return _formatDuration(dur);
  }

  String _formatDuration(Duration dur) {
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    final seconds = dur.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Get total volume for the workout
  double get totalVolume {
    return exercises.fold(0, (sum, ex) => sum + ex.totalVolume);
  }

  /// Get total number of sets
  int get totalSets {
    return exercises.fold(0, (sum, ex) => sum + ex.sets.length);
  }

  /// Get number of completed sets
  int get completedSets {
    return exercises.fold(0, (sum, ex) => sum + ex.completedSets);
  }

  /// Check if workout is completed
  bool get isCompleted => endTime != null;

  /// Check if workout is in progress
  bool get isInProgress => endTime == null && !isTemplate;

  /// Get list of unique muscle groups worked
  List<String> get muscleGroups {
    // This would need exercise data to determine,
    // for now return empty - to be populated from exercise lookup
    return [];
  }

  /// Get a summary string of exercises
  String get exerciseSummary {
    if (exercises.isEmpty) return 'No exercises';
    final names = exercises.map((e) => e.exerciseName).take(3).join(', ');
    if (exercises.length > 3) {
      return '$names...';
    }
    return names;
  }

  @override
  String toString() {
    return 'Workout(id: $id, name: $name, exercises: ${exercises.length}, '
        'startTime: $startTime, endTime: $endTime)';
  }
}

/// Represents a workout routine (template)
class Routine {
  final String id;
  final String name;
  final String? description;
  final List<RoutineExercise> exercises;
  final List<int> scheduledWeekdays; // 1..7 (Mon..Sun)
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int timesUsed;

  Routine({
    String? id,
    required this.name,
    this.description,
    List<RoutineExercise>? exercises,
    List<int>? scheduledWeekdays,
    DateTime? createdAt,
    this.lastUsedAt,
    this.timesUsed = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       exercises = exercises ?? [],
       scheduledWeekdays = _normalizeScheduledWeekdays(scheduledWeekdays);

  factory Routine.fromMap(
    Map<String, dynamic> map,
    List<RoutineExercise> exercises,
  ) {
    return Routine(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      exercises: exercises,
      scheduledWeekdays: _parseScheduledWeekdays(
        map['scheduled_weekdays'] as String?,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      timesUsed: map['times_used'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'scheduled_weekdays': scheduledWeekdays.join(','),
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
      'times_used': timesUsed,
    };
  }

  Routine copyWith({
    String? id,
    String? name,
    String? description,
    List<RoutineExercise>? exercises,
    List<int>? scheduledWeekdays,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? timesUsed,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }

  /// True when all weekdays are selected.
  bool get isEveryday => scheduledWeekdays.length == 7;

  /// Returns whether this routine is planned for the provided date.
  bool isPlannedForDate(DateTime date) {
    return scheduledWeekdays.contains(date.weekday);
  }

  static List<int> _parseScheduledWeekdays(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return List<int>.generate(7, (i) => i + 1);
    }

    final parsed = raw
        .split(',')
        .map((v) => int.tryParse(v.trim()))
        .whereType<int>()
        .toList();
    return _normalizeScheduledWeekdays(parsed);
  }

  static List<int> _normalizeScheduledWeekdays(List<int>? values) {
    final source = (values == null || values.isEmpty)
        ? List<int>.generate(7, (i) => i + 1)
        : values;

    final set = source.where((v) => v >= 1 && v <= 7).toSet().toList()..sort();
    return set.isEmpty ? List<int>.generate(7, (i) => i + 1) : set;
  }

  /// Get a summary string of exercises
  String get exerciseSummary {
    if (exercises.isEmpty) return 'No exercises';
    final names = exercises.map((e) => e.exerciseName).join(', ');
    if (names.length > 60) {
      return '${names.substring(0, 60)}...';
    }
    return names;
  }

  @override
  String toString() {
    return 'Routine(id: $id, name: $name, exercises: ${exercises.length})';
  }
}

/// Represents an exercise within a routine template
class RoutineExercise {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int order;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final double? targetDuration;
  final String? notes;
  final String? supersetId;
  final String? setTypes; // Comma-separated list of set types (e.g., "W,N,D,F")

  RoutineExercise({
    String? id,
    required this.exerciseId,
    required this.exerciseName,
    required this.order,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.targetDuration,
    this.notes,
    this.supersetId,
    this.setTypes,
  }) : id = id ?? const Uuid().v4();

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      exerciseName: map['exercise_name'] as String,
      order: map['exercise_order'] as int,
      targetSets: map['target_sets'] as int? ?? 3,
      targetReps: map['target_reps'] as int?,
      targetWeight: map['target_weight'] as double?,
      targetDuration: map['target_duration'] as double?,
      notes: map['notes'] as String?,
      supersetId: map['superset_id'] as String?,
      setTypes: map['set_types'] as String?,
    );
  }

  Map<String, dynamic> toMap(String routineId) {
    return {
      'id': id,
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'exercise_order': order,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight': targetWeight,
      'target_duration': targetDuration,
      'notes': notes,
      'superset_id': supersetId,
      'set_types': setTypes,
    };
  }

  RoutineExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    int? order,
    int? targetSets,
    int? targetReps,
    double? targetWeight,
    double? targetDuration,
    String? notes,
    String? supersetId,
    String? setTypes,
  }) {
    return RoutineExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      order: order ?? this.order,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeight: targetWeight ?? this.targetWeight,
      targetDuration: targetDuration ?? this.targetDuration,
      notes: notes ?? this.notes,
      supersetId: supersetId ?? this.supersetId,
      setTypes: setTypes ?? this.setTypes,
    );
  }

  /// Convert to WorkoutExercise for starting a workout
  WorkoutExercise toWorkoutExercise() {
    final types = setTypes?.split(',') ?? [];

    final sets = List.generate(targetSets, (index) {
      final type = index < types.length ? types[index] : 'N';
      return WorkoutSet(
        setNumber: index + 1,
        weight: targetWeight,
        reps: targetReps,
        duration: targetDuration,
        isWarmup: type == 'W',
        isDropSet: type == 'D',
        isFailure: type == 'F',
      );
    });

    return WorkoutExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      order: order,
      sets: sets,
      notes: notes,
      supersetId: supersetId,
    );
  }

  @override
  String toString() {
    return 'RoutineExercise(id: $id, exerciseName: $exerciseName, '
        'targetSets: $targetSets, order: $order)';
  }
}
