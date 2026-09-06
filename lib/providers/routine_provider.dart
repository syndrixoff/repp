import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class RoutineProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Routine> _routines = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize and load all routines
  Future<void> loadRoutines() async {
    _isLoading = true;
    notifyListeners();

    try {
      _routines = await _db.getAllRoutines();
      _error = null;
    } catch (e) {
      _error = 'Failed to load routines: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get a routine by ID
  Routine? getRoutineById(String id) {
    try {
      return _routines.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new routine
  Future<Routine?> createRoutine({
    required String name,
    String? description,
    List<RoutineExercise>? exercises,
    List<int>? scheduledWeekdays,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final routine = Routine(
        name: name,
        description: description,
        exercises: exercises ?? [],
        scheduledWeekdays: scheduledWeekdays,
      );

      await _db.insertRoutine(routine);
      _routines.insert(0, routine);
      _error = null;

      _isLoading = false;
      notifyListeners();

      return routine;
    } catch (e) {
      _error = 'Failed to create routine: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an existing routine
  Future<bool> updateRoutine(Routine routine) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.updateRoutine(routine);

      final index = _routines.indexWhere((r) => r.id == routine.id);
      if (index >= 0) {
        _routines[index] = routine;
      }

      _error = null;
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Failed to update routine: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a routine
  Future<bool> deleteRoutine(String id) async {
    try {
      await _db.deleteRoutine(id);
      _routines.removeWhere((r) => r.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete routine: $e';
      notifyListeners();
      return false;
    }
  }

  // Duplicate routine functionality removed.
  // If duplication is needed in future, reintroduce a dedicated helper here
  // that carefully clones the Routine and its exercises with new identifiers.

  /// Add an exercise to a routine
  Future<bool> addExerciseToRoutine(
    String routineId, {
    required String exerciseId,
    required String exerciseName,
    int targetSets = 3,
    int? targetReps,
    double? targetWeight,
    double? targetDuration,
  }) async {
    final routine = getRoutineById(routineId);
    if (routine == null) return false;

    final newExercise = RoutineExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      order: routine.exercises.length,
      targetSets: targetSets,
      targetReps: targetReps,
      targetWeight: targetWeight,
      targetDuration: targetDuration,
    );

    final updatedRoutine = routine.copyWith(
      exercises: [...routine.exercises, newExercise],
    );

    return updateRoutine(updatedRoutine);
  }

  /// Remove an exercise from a routine
  Future<bool> removeExerciseFromRoutine(
    String routineId,
    int exerciseIndex,
  ) async {
    final routine = getRoutineById(routineId);
    if (routine == null || exerciseIndex >= routine.exercises.length) {
      return false;
    }

    final updatedExercises = List<RoutineExercise>.from(routine.exercises);
    updatedExercises.removeAt(exerciseIndex);

    // Re-order remaining exercises
    for (int i = 0; i < updatedExercises.length; i++) {
      updatedExercises[i] = updatedExercises[i].copyWith(order: i);
    }

    final updatedRoutine = routine.copyWith(exercises: updatedExercises);
    return updateRoutine(updatedRoutine);
  }

  /// Reorder exercises in a routine
  Future<bool> reorderExercisesInRoutine(
    String routineId,
    int oldIndex,
    int newIndex,
  ) async {
    final routine = getRoutineById(routineId);
    if (routine == null) return false;

    final updatedExercises = List<RoutineExercise>.from(routine.exercises);

    if (newIndex > oldIndex) newIndex -= 1;
    final exercise = updatedExercises.removeAt(oldIndex);
    updatedExercises.insert(newIndex, exercise);

    // Re-order all exercises
    for (int i = 0; i < updatedExercises.length; i++) {
      updatedExercises[i] = updatedExercises[i].copyWith(order: i);
    }

    final updatedRoutine = routine.copyWith(exercises: updatedExercises);
    return updateRoutine(updatedRoutine);
  }

  /// Update an exercise in a routine
  Future<bool> updateExerciseInRoutine(
    String routineId,
    int exerciseIndex,
    RoutineExercise updatedExercise,
  ) async {
    final routine = getRoutineById(routineId);
    if (routine == null || exerciseIndex >= routine.exercises.length) {
      return false;
    }

    final updatedExercises = List<RoutineExercise>.from(routine.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    final updatedRoutine = routine.copyWith(exercises: updatedExercises);
    return updateRoutine(updatedRoutine);
  }

  /// Get most recently used routines
  List<Routine> getRecentRoutines({int limit = 5}) {
    final sorted = List<Routine>.from(_routines);
    sorted.sort((a, b) {
      if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
      if (a.lastUsedAt == null) return 1;
      if (b.lastUsedAt == null) return -1;
      return b.lastUsedAt!.compareTo(a.lastUsedAt!);
    });
    return sorted.take(limit).toList();
  }

  /// Get most used routines
  List<Routine> getMostUsedRoutines({int limit = 5}) {
    final sorted = List<Routine>.from(_routines);
    sorted.sort((a, b) => b.timesUsed.compareTo(a.timesUsed));
    return sorted.take(limit).toList();
  }

  /// Search routines by name
  List<Routine> searchRoutines(String query) {
    if (query.isEmpty) return _routines;

    final queryLower = query.toLowerCase();
    return _routines.where((r) {
      return r.name.toLowerCase().contains(queryLower) ||
          (r.description?.toLowerCase().contains(queryLower) ?? false) ||
          r.exercises.any(
            (e) => e.exerciseName.toLowerCase().contains(queryLower),
          );
    }).toList();
  }

  /// Clear any error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
