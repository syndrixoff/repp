import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Solo Leveling-inspired level & title system
class LevelSystem {
  LevelSystem._();

  /// XP required to reach level n (quadratic curve — gets harder every level)
  /// Level 1: 100, Level 10: 10,000, Level 30: 90,000, Level 40: 160,000
  static int xpForLevel(int level) => 100 * level * level;

  /// Cumulative XP required to reach a given level
  static int cumulativeXPForLevel(int level) {
    int total = 0;
    for (int i = 1; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// Calculate level from total cumulative XP
  static int levelFromXP(int totalXP) {
    int level = 0;
    int cumulative = 0;
    while (true) {
      final nextLevelXP = xpForLevel(level + 1);
      if (cumulative + nextLevelXP > totalXP) break;
      cumulative += nextLevelXP;
      level++;
    }
    return level;
  }

  /// XP progress within the current level (how much earned toward next)
  static int xpInCurrentLevel(int totalXP) {
    final level = levelFromXP(totalXP);
    return totalXP - cumulativeXPForLevel(level);
  }

  /// XP needed for the next level
  static int xpToNextLevel(int totalXP) {
    final level = levelFromXP(totalXP);
    return xpForLevel(level + 1);
  }

  /// Progress percentage toward next level (0.0 to 1.0)
  static double progressPercent(int totalXP) {
    final needed = xpToNextLevel(totalXP);
    if (needed == 0) return 1.0;
    final earned = xpInCurrentLevel(totalXP);
    return (earned / needed).clamp(0.0, 1.0);
  }

  /// Title for a given level (Solo Leveling ranks)
  static String titleForLevel(int level) {
    if (level >= 40) return 'National Level Hunter';
    if (level >= 30) return 'S-Rank Hunter';
    if (level >= 20) return 'A-Rank Hunter';
    if (level >= 15) return 'B-Rank Hunter';
    if (level >= 10) return 'C-Rank Hunter';
    if (level >= 5) return 'D-Rank Hunter';
    return 'E-Rank Hunter';
  }

  /// Short rank letter for badges
  static String rankLetter(int level) {
    if (level >= 40) return 'NL';
    if (level >= 30) return 'S';
    if (level >= 20) return 'A';
    if (level >= 15) return 'B';
    if (level >= 10) return 'C';
    if (level >= 5) return 'D';
    return 'E';
  }
}

class MuscleRankSystem {
  MuscleRankSystem._();

  static const List<String> _rankNames = [
    'Iron',
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Master',
    'Legend',
  ];

  // 24 steps: 8 ranks x 3 sub-ranks (I/II/III)
  static const List<int> _thresholds = [
    0,
    300,
    700,
    1200,
    1800,
    2500,
    3300,
    4300,
    5600,
    7200,
    9200,
    11700,
    14800,
    18600,
    23200,
    28800,
    35600,
    43800,
    53700,
    65500,
    79500,
    96000,
    115500,
    138500,
  ];

  static String normalizeMuscleGroup(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('chest') || value.contains('pec')) return 'Chest';
    if (value.contains('back') || value.contains('lat') || value.contains('trap')) {
      return 'Back';
    }
    if (value.contains('quad') ||
        value.contains('hamstring') ||
        value.contains('glute') ||
        value.contains('calf') ||
        value.contains('leg')) {
      return 'Legs';
    }
    if (value.contains('bicep') ||
        value.contains('tricep') ||
        value.contains('forearm') ||
        value.contains('arm')) {
      return 'Arms';
    }
    if (value.contains('shoulder') || value.contains('delt')) return 'Shoulders';
    if (value.contains('ab') || value.contains('core')) return 'Core';
    if (value.contains('cardio') || value.contains('run') || value.contains('walk')) {
      return 'Cardio';
    }
    return 'Other';
  }

  static int rankIndexFromXP(int xp) {
    int index = 0;
    for (int i = 0; i < _thresholds.length; i++) {
      if (xp >= _thresholds[i]) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  static String rankLabelFromXP(int xp) {
    final index = rankIndexFromXP(xp);
    final rank = _rankNames[index ~/ 3];
    final tier = (index % 3) + 1;
    final tierRoman = tier == 1 ? 'I' : (tier == 2 ? 'II' : 'III');
    return '$rank $tierRoman';
  }

  static String compactRankLabelFromXP(int xp) {
    final index = rankIndexFromXP(xp);
    final rank = _rankNames[index ~/ 3].toLowerCase();
    final tier = (index % 3) + 1;
    return '$rank$tier';
  }
}

/// Persistent player stats — one row in DB
class PlayerStats {
  final String id;
  final int level;
  final int totalXP;
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> muscleXP; // e.g. {"Chest": 1200, "Back": 900}
  final DateTime? lastWorkoutDate;
  final DateTime createdAt;

  PlayerStats({
    this.id = 'main',
    this.level = 0,
    this.totalXP = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.muscleXP = const {},
    this.lastWorkoutDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get title => LevelSystem.titleForLevel(level);
  String get rankLetter => LevelSystem.rankLetter(level);
  int get xpInCurrentLevel => LevelSystem.xpInCurrentLevel(totalXP);
  int get xpToNextLevel => LevelSystem.xpToNextLevel(totalXP);
  double get progressPercent => LevelSystem.progressPercent(totalXP);

  PlayerStats copyWith({
    int? level,
    int? totalXP,
    int? currentStreak,
    int? longestStreak,
    Map<String, int>? muscleXP,
    DateTime? lastWorkoutDate,
  }) {
    return PlayerStats(
      id: id,
      level: level ?? this.level,
      totalXP: totalXP ?? this.totalXP,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      muscleXP: muscleXP ?? this.muscleXP,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level,
      'total_xp': totalXP,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'muscle_xp': jsonEncode(muscleXP),
      'last_workout_date': lastWorkoutDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    Map<String, int> muscleMap = {};
    if (map['muscle_xp'] != null && map['muscle_xp'] is String) {
      final decoded = jsonDecode(map['muscle_xp'] as String);
      if (decoded is Map) {
        muscleMap = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    }

    return PlayerStats(
      id: map['id'] as String? ?? 'main',
      level: map['level'] as int? ?? 0,
      totalXP: map['total_xp'] as int? ?? 0,
      currentStreak: map['current_streak'] as int? ?? 0,
      longestStreak: map['longest_streak'] as int? ?? 0,
      muscleXP: muscleMap,
      lastWorkoutDate: map['last_workout_date'] != null
          ? DateTime.tryParse(map['last_workout_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Individual XP gain entry (log table)
class XPLog {
  final String id;
  final String? workoutId;
  final int amount;
  final String source; // 'set_complete', 'workout_complete', 'streak_bonus', 'pr_bonus'
  final String? details;
  final DateTime createdAt;

  XPLog({
    String? id,
    this.workoutId,
    required this.amount,
    required this.source,
    this.details,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'amount': amount,
      'source': source,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory XPLog.fromMap(Map<String, dynamic> map) {
    return XPLog(
      id: map['id'] as String,
      workoutId: map['workout_id'] as String?,
      amount: map['amount'] as int,
      source: map['source'] as String,
      details: map['details'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String) ?? DateTime.now(),
    );
  }
}

/// Result from an XP award — passed to the workout complete screen
class XPAwardResult {
  final int totalXPGained;
  final int setXP;
  final int repsXP;
  final int weightXP;
  final int completionXP;
  final int streakXP;
  final int prXP;
  final Map<String, int> muscleXPGains;
  final int previousLevel;
  final int newLevel;
  final int previousTotalXP;
  final int newTotalXP;
  final bool didLevelUp;
  final String? newTitle;
  final int completedSetCount;
  final int personalRecordSetCount;
  final List<String> muscleRankUps;
  final bool didAnyMuscleRankUp;

  XPAwardResult({
    required this.totalXPGained,
    required this.setXP,
    required this.repsXP,
    required this.weightXP,
    required this.completionXP,
    required this.streakXP,
    required this.prXP,
    required this.muscleXPGains,
    required this.previousLevel,
    required this.newLevel,
    required this.previousTotalXP,
    required this.newTotalXP,
    required this.didLevelUp,
    this.newTitle,
    this.completedSetCount = 0,
    this.personalRecordSetCount = 0,
    this.muscleRankUps = const [],
    this.didAnyMuscleRankUp = false,
  });
}
