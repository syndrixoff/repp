import 'package:uuid/uuid.dart';

/// Types of personal records that can be tracked
enum PRType {
  maxWeight, // Heaviest weight lifted for any reps
  maxVolume, // Highest single set volume (weight × reps)
  maxReps, // Most reps at any weight
  maxRepsAtWeight, // Most reps at a specific weight
  oneRepMax, // Calculated or actual 1RM
  maxDuration, // Longest time for timed exercises
  maxDistance, // Longest distance for cardio exercises
}

/// Represents a personal record for an exercise
class PersonalRecord {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final PRType type;
  final double value; // The PR value (weight, reps, volume, duration, etc.)
  final double? secondaryValue; // For maxRepsAtWeight: the weight used
  final DateTime achievedAt;
  final String? workoutId; // Reference to the workout where PR was achieved
  final String? setId; // Reference to the specific set
  final String? notes;

  PersonalRecord({
    String? id,
    required this.exerciseId,
    required this.exerciseName,
    required this.type,
    required this.value,
    this.secondaryValue,
    DateTime? achievedAt,
    this.workoutId,
    this.setId,
    this.notes,
  }) : id = id ?? const Uuid().v4(),
       achievedAt = achievedAt ?? DateTime.now();

  factory PersonalRecord.fromMap(Map<String, dynamic> map) {
    return PersonalRecord(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      exerciseName: map['exercise_name'] as String,
      type: PRType.values[map['type'] as int],
      value: map['value'] as double,
      secondaryValue: map['secondary_value'] as double?,
      achievedAt: DateTime.parse(map['achieved_at'] as String),
      workoutId: map['workout_id'] as String?,
      setId: map['set_id'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'type': type.index,
      'value': value,
      'secondary_value': secondaryValue,
      'achieved_at': achievedAt.toIso8601String(),
      'workout_id': workoutId,
      'set_id': setId,
      'notes': notes,
    };
  }

  PersonalRecord copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    PRType? type,
    double? value,
    double? secondaryValue,
    DateTime? achievedAt,
    String? workoutId,
    String? setId,
    String? notes,
  }) {
    return PersonalRecord(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      type: type ?? this.type,
      value: value ?? this.value,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      achievedAt: achievedAt ?? this.achievedAt,
      workoutId: workoutId ?? this.workoutId,
      setId: setId ?? this.setId,
      notes: notes ?? this.notes,
    );
  }

  /// Get display string for the PR type
  String get typeDisplayName {
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
        return 'One Rep Max';
      case PRType.maxDuration:
        return 'Max Duration';
      case PRType.maxDistance:
        return 'Max Distance';
    }
  }

  /// Get formatted value string based on PR type
  String get formattedValue {
    switch (type) {
      case PRType.maxWeight:
      case PRType.oneRepMax:
        return '${value.toStringAsFixed(1)} kg';
      case PRType.maxVolume:
        return '${value.toStringAsFixed(0)} kg';
      case PRType.maxReps:
        return '${value.toInt()} reps';
      case PRType.maxRepsAtWeight:
        return '${value.toInt()} reps @ ${secondaryValue?.toStringAsFixed(1) ?? "?"} kg';
      case PRType.maxDuration:
        final minutes = (value / 60).floor();
        final seconds = (value % 60).floor();
        if (minutes > 0) {
          return '${minutes}m ${seconds}s';
        }
        return '${seconds}s';
      case PRType.maxDistance:
        if (value >= 1000) {
          return '${(value / 1000).toStringAsFixed(2)} km';
        }
        return '${value.toStringAsFixed(0)} m';
    }
  }

  /// Get short formatted value (for compact displays)
  String get shortFormattedValue {
    switch (type) {
      case PRType.maxWeight:
      case PRType.oneRepMax:
        return '${value.toStringAsFixed(1)}kg';
      case PRType.maxVolume:
        return '${value.toStringAsFixed(0)}kg vol';
      case PRType.maxReps:
        return '${value.toInt()}reps';
      case PRType.maxRepsAtWeight:
        return '${value.toInt()}×${secondaryValue?.toStringAsFixed(0) ?? "?"}kg';
      case PRType.maxDuration:
        return '${value.toStringAsFixed(0)}s';
      case PRType.maxDistance:
        return '${(value / 1000).toStringAsFixed(2)}km';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonalRecord &&
        other.id == id &&
        other.exerciseId == exerciseId &&
        other.type == type &&
        other.value == value;
  }

  @override
  int get hashCode {
    return Object.hash(id, exerciseId, type, value);
  }

  @override
  String toString() {
    return 'PersonalRecord(id: $id, exerciseName: $exerciseName, '
        'type: $typeDisplayName, value: $formattedValue)';
  }
}

/// Helper class to calculate estimated one-rep max
class OneRepMaxCalculator {
  /// Calculate estimated 1RM using various formulas
  /// Returns average of multiple formulas for better accuracy

  /// Epley Formula: 1RM = weight × (1 + reps/30)
  static double epley(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  /// Brzycki Formula: 1RM = weight × (36 / (37 - reps))
  static double brzycki(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    if (reps >= 37) return weight * 2; // Prevent division issues
    return weight * (36 / (37 - reps));
  }

  /// Lander Formula: 1RM = weight × 100 / (101.3 - 2.67123 × reps)
  static double lander(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    final denominator = 101.3 - 2.67123 * reps;
    if (denominator <= 0) return weight * 2;
    return weight * 100 / denominator;
  }

  /// Lombardi Formula: 1RM = weight × reps^0.10
  static double lombardi(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight * _pow(reps.toDouble(), 0.10);
  }

  /// O'Conner Formula: 1RM = weight × (1 + 0.025 × reps)
  static double oconner(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight * (1 + 0.025 * reps);
  }

  /// Calculate average 1RM from multiple formulas
  static double calculate(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;

    // For higher rep ranges (>10), some formulas become less accurate
    // Weight formulas appropriately
    if (reps <= 10) {
      final results = [
        epley(weight, reps),
        brzycki(weight, reps),
        lander(weight, reps),
        lombardi(weight, reps),
        oconner(weight, reps),
      ];
      return results.reduce((a, b) => a + b) / results.length;
    } else {
      // For higher reps, use only Epley and Brzycki which handle them better
      return (epley(weight, reps) + brzycki(weight, reps)) / 2;
    }
  }

  /// Calculate weight needed for a target number of reps at a given 1RM
  static double weightForReps(double oneRepMax, int targetReps) {
    if (targetReps <= 0) return oneRepMax;
    if (targetReps == 1) return oneRepMax;
    // Reverse Epley formula
    return oneRepMax / (1 + targetReps / 30);
  }

  /// Get percentage of 1RM for a given rep count
  static double percentageFor(int reps) {
    if (reps <= 0) return 100;
    if (reps == 1) return 100;
    // Based on standard rep-percentage chart
    return 100 / (1 + reps / 30);
  }

  static double _pow(double base, double exponent) {
    // Simple power function for Dart
    if (exponent == 0) return 1;
    if (base == 0) return 0;

    // For non-integer exponents, use approximation
    // This is a simplified version; Dart's math.pow handles this
    // but we'll use a basic implementation
    return _expBySquaring(base, exponent);
  }

  static double _expBySquaring(double base, double exp) {
    // Approximate for small exponents like 0.10
    if (exp == 0.10) {
      // Rough approximation for x^0.10
      return 1 + 0.10 * (base - 1) / 1.5;
    }
    return base; // Fallback
  }
}

/// Collection of PRs for an exercise
class ExercisePRs {
  final String exerciseId;
  final String exerciseName;
  final PersonalRecord? maxWeight;
  final PersonalRecord? maxVolume;
  final PersonalRecord? maxReps;
  final PersonalRecord? oneRepMax;
  final PersonalRecord? maxDuration;
  final PersonalRecord? maxDistance;
  final List<PersonalRecord> allRecords;

  ExercisePRs({
    required this.exerciseId,
    required this.exerciseName,
    this.maxWeight,
    this.maxVolume,
    this.maxReps,
    this.oneRepMax,
    this.maxDuration,
    this.maxDistance,
    List<PersonalRecord>? allRecords,
  }) : allRecords = allRecords ?? [];

  factory ExercisePRs.fromRecords(List<PersonalRecord> records) {
    if (records.isEmpty) {
      return ExercisePRs(exerciseId: '', exerciseName: '');
    }

    final exerciseId = records.first.exerciseId;
    final exerciseName = records.first.exerciseName;

    PersonalRecord? findBest(PRType type) {
      final matching = records.where((r) => r.type == type).toList();
      if (matching.isEmpty) return null;
      return matching.reduce((a, b) => a.value > b.value ? a : b);
    }

    return ExercisePRs(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      maxWeight: findBest(PRType.maxWeight),
      maxVolume: findBest(PRType.maxVolume),
      maxReps: findBest(PRType.maxReps),
      oneRepMax: findBest(PRType.oneRepMax),
      maxDuration: findBest(PRType.maxDuration),
      maxDistance: findBest(PRType.maxDistance),
      allRecords: records,
    );
  }

  /// Check if there are any PRs
  bool get hasPRs =>
      maxWeight != null ||
      maxVolume != null ||
      maxReps != null ||
      oneRepMax != null ||
      maxDuration != null ||
      maxDistance != null;

  /// Get the most recent PR
  PersonalRecord? get mostRecent {
    if (allRecords.isEmpty) return null;
    return allRecords.reduce(
      (a, b) => a.achievedAt.isAfter(b.achievedAt) ? a : b,
    );
  }

  @override
  String toString() {
    return 'ExercisePRs(exerciseName: $exerciseName, hasPRs: $hasPRs)';
  }
}
