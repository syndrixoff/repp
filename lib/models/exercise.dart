import 'package:flutter/foundation.dart';

class Exercise {
  final String id;
  final String name;
  final String equipment;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? howTo;
  final bool isCustom;

  Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.primaryMuscle,
    this.secondaryMuscles = const [],
    this.videoUrl,
    this.thumbnailUrl,
    this.howTo,
    this.isCustom = false,
  });

  /// Parse howTo string (pipe-separated steps) into a list of instruction strings.
  /// Each step is expected to look like "1. Do something." separated by " | ".
  List<String> get howToSteps {
    if (howTo == null || howTo!.trim().isEmpty) return [];
    return howTo!
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  factory Exercise.fromCsv(List<dynamic> row) {
    final name = row[0]?.toString() ?? '';
    final equipment = row[1]?.toString() ?? 'None';
    final primaryMuscle = row[2]?.toString() ?? 'Other';
    final secondaryMuscleStr = row[3]?.toString() ?? 'None';
    final videoUrl = row[4]?.toString();
    final thumbnailUrl = row[5]?.toString();
    final howTo = row.length > 6 ? row[6]?.toString() : null;

    // Parse secondary muscles (comma-separated)
    List<String> secondaryMuscles = [];
    if (secondaryMuscleStr != 'None' && secondaryMuscleStr.isNotEmpty) {
      secondaryMuscles = secondaryMuscleStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Generate ID from name (lowercase, no spaces)
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    return Exercise(
      id: id,
      name: name,
      equipment: equipment,
      primaryMuscle: primaryMuscle,
      secondaryMuscles: secondaryMuscles,
      videoUrl: videoUrl != 'None' && videoUrl != null && videoUrl.isNotEmpty
          ? videoUrl
          : null,
      thumbnailUrl:
          thumbnailUrl != 'None' &&
              thumbnailUrl != null &&
              thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : null,
      howTo: howTo != null && howTo != 'None' && howTo.trim().isNotEmpty
          ? howTo.trim()
          : null,
      isCustom: false,
    );
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      equipment: map['equipment'] as String? ?? 'None',
      primaryMuscle: map['primary_muscle'] as String? ?? 'Other',
      secondaryMuscles: (map['secondary_muscles'] as String?)?.split(',') ?? [],
      videoUrl: map['video_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      howTo: map['how_to'] as String?,
      isCustom: (map['is_custom'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'equipment': equipment,
      'primary_muscle': primaryMuscle,
      'secondary_muscles': secondaryMuscles.join(','),
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'how_to': howTo,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? equipment,
    String? primaryMuscle,
    List<String>? secondaryMuscles,
    String? videoUrl,
    String? thumbnailUrl,
    String? howTo,
    bool? isCustom,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      equipment: equipment ?? this.equipment,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      howTo: howTo ?? this.howTo,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise &&
        other.id == id &&
        other.name == name &&
        other.equipment == equipment &&
        other.primaryMuscle == primaryMuscle &&
        listEquals(other.secondaryMuscles, secondaryMuscles);
  }

  @override
  int get hashCode {
    return Object.hash(id, name, equipment, primaryMuscle, secondaryMuscles);
  }

  @override
  String toString() {
    return 'Exercise(id: $id, name: $name, equipment: $equipment, '
        'primaryMuscle: $primaryMuscle, secondaryMuscles: $secondaryMuscles, '
        'howTo: ${howTo != null ? "yes" : "no"})';
  }
}

// Equipment types
class EquipmentType {
  static const String none = 'None';
  static const String barbell = 'Barbell';
  static const String dumbbell = 'Dumbbell';
  static const String machine = 'Machine';
  static const String cable = 'Cable';
  static const String kettlebell = 'Kettlebell';
  static const String plate = 'Plate';
  static const String resistanceBand = 'Resistance Band';
  static const String suspension = 'Suspension';
  static const String other = 'Other';

  static const List<String> all = [
    none,
    barbell,
    dumbbell,
    machine,
    cable,
    kettlebell,
    plate,
    resistanceBand,
    suspension,
    other,
  ];

  /// Equipment types that only need sets & reps (no weight column).
  static const List<String> bodyweightOnly = [none, resistanceBand, suspension];

  /// Returns true if the equipment type typically needs a weight input.
  static bool needsWeight(String equipment) {
    return !bodyweightOnly.contains(equipment);
  }
}

// Cardio exercise classification
class CardioType {
  /// Exercises that track distance + time (locomotion-based)
  static const List<String> distanceCardio = [
    'Running',
    'Treadmill',
    'Cycling',
    'Swimming',
    'Walking',
    'Hiking',
    'Sprints',
    'Skating',
    'Skiing',
    'Snowboarding',
    'Climbing',
    'Rowing Machine',
    'Elliptical Trainer',
  ];

  /// Exercises that track time only (stationary/repetitive)
  static const List<String> timeOnlyCardio = [
    'Jump Rope',
    'Battle Ropes',
    'Boxing',
    'Air Bike',
    'Spinning',
    'Stair Machine (Floors)',
    'Stair Machine (Steps)',
    'Aerobics',
    'HIIT',
  ];

  /// Returns true if the exercise's primary muscle is Cardio.
  static bool isCardio(String primaryMuscle) => primaryMuscle == 'Cardio';

  /// Returns true if this cardio exercise should track distance.
  static bool needsDistance(String exerciseName) =>
      distanceCardio.contains(exerciseName);

  /// Returns true if this cardio exercise tracks time only.
  static bool isTimeOnly(String exerciseName) =>
      timeOnlyCardio.contains(exerciseName);
}

// Muscle groups
class MuscleGroup {
  static const String chest = 'Chest';
  static const String back = 'Back';
  static const String upperBack = 'Upper Back';
  static const String lowerBack = 'Lower Back';
  static const String lats = 'Lats';
  static const String shoulders = 'Shoulders';
  static const String biceps = 'Biceps';
  static const String triceps = 'Triceps';
  static const String forearms = 'Forearms';
  static const String abdominals = 'Abdominals';
  static const String abductors = 'Abductors';
  static const String adductors = 'Adductors';
  static const String quadriceps = 'Quadriceps';
  static const String hamstrings = 'Hamstrings';
  static const String glutes = 'Glutes';
  static const String calves = 'Calves';
  static const String traps = 'Traps';
  static const String neck = 'Neck';
  static const String fullBody = 'Full Body';
  static const String cardio = 'Cardio';
  static const String other = 'Other';

  static const List<String> all = [
    chest,
    back,
    upperBack,
    lowerBack,
    lats,
    shoulders,
    biceps,
    triceps,
    forearms,
    abdominals,
    abductors,
    adductors,
    quadriceps,
    hamstrings,
    glutes,
    calves,
    traps,
    neck,
    fullBody,
    cardio,
    other,
  ];

  // For filtering - main muscle groups
  static const List<String> primary = [
    chest,
    back,
    shoulders,
    biceps,
    triceps,
    abdominals,
    abductors,
    adductors,
    quadriceps,
    hamstrings,
    glutes,
    calves,
    traps,
    neck,
    cardio,
  ];
}
