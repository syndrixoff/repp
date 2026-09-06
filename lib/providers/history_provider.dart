import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class HistoryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Workout> _workoutHistory = [];
  Map<String, dynamic> _stats = {};
  List<PersonalRecord> _recentPRs = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  // Getters
  List<Workout> get workoutHistory => _workoutHistory;
  Map<String, dynamic> get stats => _stats;
  List<PersonalRecord> get recentPRs => _recentPRs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  // Statistics getters
  int get totalWorkouts => _stats['total_workouts'] ?? 0;
  double get totalVolume => _stats['total_volume'] ?? 0.0;
  int get totalSets => _stats['total_sets'] ?? 0;
  double get avgDurationMinutes => _stats['avg_duration_minutes'] ?? 0.0;
  int get thisWeekWorkouts => _stats['this_week_workouts'] ?? 0;

  /// Initialize and load history
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadWorkoutHistory(),
        _loadStats(),
        _loadRecentPRs(),
      ]);
      _error = null;
    } catch (e) {
      _error = 'Failed to load history: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load initial workout history
  Future<void> _loadWorkoutHistory() async {
    _currentPage = 0;
    _hasMore = true;
    _workoutHistory = await _db.getAllWorkouts(limit: _pageSize, offset: 0);
    _hasMore = _workoutHistory.length >= _pageSize;
  }

  /// Load more workout history (pagination)
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      _currentPage++;
      final moreWorkouts = await _db.getAllWorkouts(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      _workoutHistory.addAll(moreWorkouts);
      _hasMore = moreWorkouts.length >= _pageSize;
      _error = null;
    } catch (e) {
      _error = 'Failed to load more workouts: $e';
      _currentPage--;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh all history data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadWorkoutHistory(),
        _loadStats(),
        _loadRecentPRs(),
      ]);
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh history: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load statistics
  Future<void> _loadStats() async {
    _stats = await _db.getWorkoutStats();
  }

  /// Load recent personal records
  Future<void> _loadRecentPRs() async {
    final allPRs = await _db.getAllPersonalRecords();
    _recentPRs = allPRs.take(10).toList();
  }

  /// Get workouts for a specific date range
  Future<List<Workout>> getWorkoutsInRange(DateTime start, DateTime end) async {
    try {
      return await _db.getWorkoutsInRange(start, end);
    } catch (e) {
      _error = 'Failed to load workouts for date range: $e';
      notifyListeners();
      return [];
    }
  }

  /// Get workout by ID
  Future<Workout?> getWorkoutById(String id) async {
    // First check in memory
    try {
      return _workoutHistory.firstWhere((w) => w.id == id);
    } catch (e) {
      // Not in memory, load from database
      try {
        return await _db.getWorkout(id);
      } catch (e) {
        _error = 'Failed to load workout: $e';
        notifyListeners();
        return null;
      }
    }
  }

  /// Get workout by ID from currently loaded history only.
  Workout? getCachedWorkoutById(String id) {
    try {
      return _workoutHistory.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a workout from history
  Future<bool> deleteWorkout(String id) async {
    try {
      await _db.deleteWorkout(id);
      _workoutHistory.removeWhere((w) => w.id == id);

      // Refresh stats
      await _loadStats();

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete workout: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get workouts grouped by date (for calendar view)
  Map<DateTime, List<Workout>> getWorkoutsByDate() {
    final Map<DateTime, List<Workout>> grouped = {};

    for (final workout in _workoutHistory) {
      final date = DateTime(
        workout.startTime.year,
        workout.startTime.month,
        workout.startTime.day,
      );

      if (grouped.containsKey(date)) {
        grouped[date]!.add(workout);
      } else {
        grouped[date] = [workout];
      }
    }

    return grouped;
  }

  /// Get workouts for a specific month
  List<Workout> getWorkoutsForMonth(int year, int month) {
    return _workoutHistory.where((w) {
      return w.startTime.year == year && w.startTime.month == month;
    }).toList();
  }

  /// Get workout count for a specific week
  int getWorkoutCountForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _workoutHistory.where((w) {
      return w.startTime.isAfter(weekStart) && w.startTime.isBefore(weekEnd);
    }).length;
  }

  /// Get volume data for charting (last N days)
  Future<List<Map<String, dynamic>>> getVolumeChartData({int days = 30}) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    try {
      return await _db.getVolumeByMuscleGroup(start, end);
    } catch (e) {
      _error = 'Failed to load volume data: $e';
      notifyListeners();
      return [];
    }
  }

  /// Get exercise history
  Future<List<Map<String, dynamic>>> getExerciseHistory(
    String exerciseId,
  ) async {
    try {
      return await _db.getExerciseHistory(exerciseId);
    } catch (e) {
      _error = 'Failed to load exercise history: $e';
      notifyListeners();
      return [];
    }
  }

  /// Get PRs for a specific exercise
  Future<ExercisePRs> getPRsForExercise(String exerciseId) async {
    try {
      final records = await _db.getPersonalRecordsForExercise(exerciseId);
      return ExercisePRs.fromRecords(records);
    } catch (e) {
      _error = 'Failed to load PRs: $e';
      notifyListeners();
      return ExercisePRs(exerciseId: exerciseId, exerciseName: '');
    }
  }

  /// Get streak information
  Map<String, int> getStreakInfo() {
    if (_workoutHistory.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    // Sort by date descending
    final sorted = List<Workout>.from(_workoutHistory)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if there's a workout today or yesterday
    final mostRecent = sorted.first.startTime;
    final mostRecentDate = DateTime(
      mostRecent.year,
      mostRecent.month,
      mostRecent.day,
    );

    final daysDiff = todayDate.difference(mostRecentDate).inDays;

    if (daysDiff > 1) {
      // Streak is broken
      currentStreak = 0;
    } else {
      // Calculate current streak
      currentStreak = 1;
      for (int i = 1; i < sorted.length; i++) {
        final current = sorted[i].startTime;
        final previous = sorted[i - 1].startTime;

        final currentDate = DateTime(current.year, current.month, current.day);
        final previousDate = DateTime(
          previous.year,
          previous.month,
          previous.day,
        );

        final diff = previousDate.difference(currentDate).inDays;

        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          break;
        }
        // If diff == 0, same day, don't increment but continue
      }
    }

    // Calculate longest streak
    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i].startTime;
      final previous = sorted[i - 1].startTime;

      final currentDate = DateTime(current.year, current.month, current.day);
      final previousDate = DateTime(
        previous.year,
        previous.month,
        previous.day,
      );

      final diff = previousDate.difference(currentDate).inDays;

      if (diff == 1) {
        tempStreak++;
      } else if (diff > 1) {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 1;
      }
      // If diff == 0, same day, continue without incrementing
    }

    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    return {'current': currentStreak, 'longest': longestStreak};
  }

  /// Clear any error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
