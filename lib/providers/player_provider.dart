import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';

class PlayerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ExerciseService _exerciseService = ExerciseService();

  PlayerStats _stats = PlayerStats();
  List<XPLog> _recentLogs = [];
  bool _isLoading = false;

  // Getters
  PlayerStats get stats => _stats;
  List<XPLog> get recentLogs => _recentLogs;
  bool get isLoading => _isLoading;
  int get level => _stats.level;
  int get totalXP => _stats.totalXP;
  String get title => _stats.title;
  String get rankLetter => _stats.rankLetter;
  int get xpInCurrentLevel => _stats.xpInCurrentLevel;
  int get xpToNextLevel => _stats.xpToNextLevel;
  double get progressPercent => _stats.progressPercent;
  int get currentStreak => _stats.currentStreak;
  int get longestStreak => _stats.longestStreak;
  Map<String, int> get muscleXP => _stats.muscleXP;

  /// Initialize — load from DB or create fresh
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final existing = await _db.getPlayerStats();
      if (existing != null) {
        _stats = existing;
      } else {
        // First time — seed the row
        _stats = PlayerStats();
        await _db.upsertPlayerStats(_stats);
      }
      _recentLogs = await _db.getRecentXPLogs(limit: 20);
    } catch (e) {
      debugPrint('PlayerProvider init error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Award XP for a completed workout. Returns XPAwardResult for the reward screen.
  Future<XPAwardResult> awardWorkoutXP(Workout workout) async {
    final previousLevel = _stats.level;
    final previousTotalXP = _stats.totalXP;

    final completedSetCount = workout.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.completedSets,
    );

    final perSetXP = _stats.level >= 25
        ? 30
        : (_stats.level >= 10 ? 20 : 10);
    final setXP = completedSetCount * perSetXP;
    const repsXP = 0;
    const weightXP = 0;
    final Map<String, int> muscleGains = {};

    final allPRs = await _db.getAllPersonalRecords();
    final workoutPRSetIds = allPRs
        .where((pr) => pr.workoutId == workout.id && pr.setId != null)
        .map((pr) => pr.setId!)
        .toSet();
    final prSetCount = workoutPRSetIds.length;

    // Calculate per-muscle gains from completed sets and PR x2 bonuses.
    for (final exercise in workout.exercises) {
      final exerciseModel = _exerciseService.getById(exercise.exerciseId);
      final muscle = MuscleRankSystem.normalizeMuscleGroup(
        exerciseModel?.primaryMuscle ?? 'Other',
      );

      int exerciseXP = 0;

      for (final set in exercise.sets) {
        if (!set.isCompleted) continue;
        exerciseXP += perSetXP;
        if (workoutPRSetIds.contains(set.id)) {
          // PR grants a stackable x2 set bonus.
          exerciseXP += perSetXP;
        }
      }

      // Distribute to muscle group
      if (exerciseXP > 0) {
        muscleGains[muscle] = (muscleGains[muscle] ?? 0) + exerciseXP;
      }
    }

    final completionXP = _stats.level >= 25
        ? 150
        : (_stats.level >= 10 ? 110 : 75);

    // Streak handling
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int newStreak = _stats.currentStreak;

    if (_stats.lastWorkoutDate != null) {
      final lastDate = DateTime(
        _stats.lastWorkoutDate!.year,
        _stats.lastWorkoutDate!.month,
        _stats.lastWorkoutDate!.day,
      );
      final daysDiff = today.difference(lastDate).inDays;

      if (daysDiff == 1) {
        // Consecutive day — streak continues
        newStreak = _stats.currentStreak + 1;
      } else if (daysDiff > 1) {
        // Streak broken
        newStreak = 1;
      }
      // daysDiff == 0 means same day — keep current streak
    } else {
      newStreak = 1; // First workout ever
    }

    final streakMilestoneRewards = <int, int>{3: 50, 7: 150, 30: 750, 100: 3000};
    final streakXP = (newStreak != _stats.currentStreak)
        ? (streakMilestoneRewards[newStreak] ?? 0)
        : 0;

    final prXP = prSetCount * perSetXP;

    // Total
    final totalGained = setXP + repsXP + weightXP + completionXP + streakXP + prXP;
    final newTotalXP = previousTotalXP + totalGained;
    final newLevel = LevelSystem.levelFromXP(newTotalXP);
    final didLevelUp = newLevel > previousLevel;

    // Update muscle XP map and detect rank-ups.
    final updatedMuscleXP = Map<String, int>.from(_stats.muscleXP);
    final muscleRankUps = <String>[];
    for (final entry in muscleGains.entries) {
      final previousMuscleXP = updatedMuscleXP[entry.key] ?? 0;
      final previousRank = MuscleRankSystem.rankIndexFromXP(previousMuscleXP);
      final nextMuscleXP = previousMuscleXP + entry.value;
      final nextRank = MuscleRankSystem.rankIndexFromXP(nextMuscleXP);

      updatedMuscleXP[entry.key] = nextMuscleXP;

      if (nextRank > previousRank) {
        muscleRankUps.add(entry.key);
      }
    }

    final newLongestStreak = max(newStreak, _stats.longestStreak);

    // Save to DB
    _stats = _stats.copyWith(
      level: newLevel,
      totalXP: newTotalXP,
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
      muscleXP: updatedMuscleXP,
      lastWorkoutDate: now,
    );
    await _db.upsertPlayerStats(_stats);

    // Log XP entries
    if (setXP > 0) {
      await _db.insertXPLog(XPLog(
        workoutId: workout.id,
        amount: setXP,
        source: 'set_complete',
        details: 'Completed sets',
      ));
    }
    if (repsXP > 0) {
      await _db.insertXPLog(XPLog(
        workoutId: workout.id,
        amount: repsXP,
        source: 'reps_bonus',
        details: 'Rep bonus',
      ));
    }
    if (weightXP > 0) {
      await _db.insertXPLog(XPLog(
        workoutId: workout.id,
        amount: weightXP,
        source: 'weight_bonus',
        details: 'Weight bonus',
      ));
    }
    await _db.insertXPLog(XPLog(
      workoutId: workout.id,
      amount: completionXP,
      source: 'workout_complete',
      details: 'Workout completed',
    ));
    if (streakXP > 0) {
      await _db.insertXPLog(XPLog(
        workoutId: workout.id,
        amount: streakXP,
        source: 'streak_bonus',
        details: '$newStreak day streak',
      ));
    }

    _recentLogs = await _db.getRecentXPLogs(limit: 20);
    notifyListeners();

    return XPAwardResult(
      totalXPGained: totalGained,
      setXP: setXP,
      repsXP: repsXP,
      weightXP: weightXP,
      completionXP: completionXP,
      streakXP: streakXP,
      prXP: prXP,
      muscleXPGains: muscleGains,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousTotalXP: previousTotalXP,
      newTotalXP: newTotalXP,
      didLevelUp: didLevelUp,
      newTitle: didLevelUp ? LevelSystem.titleForLevel(newLevel) : null,
      completedSetCount: completedSetCount,
      personalRecordSetCount: prSetCount,
      muscleRankUps: muscleRankUps,
      didAnyMuscleRankUp: muscleRankUps.isNotEmpty,
    );
  }

  /// Refresh stats from DB
  Future<void> refresh() async {
    try {
      final existing = await _db.getPlayerStats();
      if (existing != null) {
        _stats = existing;
      }
      _recentLogs = await _db.getRecentXPLogs(limit: 20);
      notifyListeners();
    } catch (e) {
      debugPrint('PlayerProvider refresh error: $e');
    }
  }

  Future<void> addQuestXP(int amount, String questTitle) async {
    debugPrint('[PlayerProvider] Adding quest XP: +$amount for "$questTitle"');
    debugPrint('[PlayerProvider] Before: totalXP=${_stats.totalXP}, level=${_stats.level}');
    
    final newTotalXP = _stats.totalXP + amount;
    final newLevel = LevelSystem.levelFromXP(newTotalXP);
    debugPrint('[PlayerProvider] After calculation: totalXP=$newTotalXP, level=$newLevel');

    _stats = _stats.copyWith(
      level: newLevel,
      totalXP: newTotalXP,
    );
    
    try {
      await _db.upsertPlayerStats(_stats);
      debugPrint('[PlayerProvider] Successfully saved to database');
    } catch (e) {
      debugPrint('[PlayerProvider] ERROR saving to database: $e');
      rethrow;
    }

    await _db.insertXPLog(XPLog(
      amount: amount,
      source: 'quest_complete',
      details: 'Completed quest: $questTitle',
    ));
    debugPrint('[PlayerProvider] XP log inserted');

    // Reload XP logs and notify listeners to update UI
    _recentLogs = await _db.getRecentXPLogs(limit: 20);
    debugPrint('[PlayerProvider] XP logs reloaded');
    
    notifyListeners();
    debugPrint('[PlayerProvider] Notified listeners with updated stats and logs');
  }
}
