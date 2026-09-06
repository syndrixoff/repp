import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  Workout? _activeWorkout;
  bool _isLoading = false;
  String? _error;

  // Getters
  Workout? get activeWorkout => _activeWorkout;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveWorkout => _activeWorkout != null;

  /// Initialize provider - check for active workout
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeWorkout = await _db.getActiveWorkout();
      _error = null;
    } catch (e) {
      _error = 'Failed to load active workout: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Start a new empty workout
  Future<void> startEmptyWorkout() async {
    if (_activeWorkout != null) {
      _error = 'A workout is already in progress';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _activeWorkout = Workout(name: 'Workout', startTime: DateTime.now());
      await _db.insertWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to start workout: $e';
      _activeWorkout = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Start a workout from a routine
  Future<void> startFromRoutine(Routine routine) async {
    if (_activeWorkout != null) {
      _error = 'A workout is already in progress';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Convert routine exercises to workout exercises
      final workoutExercises = routine.exercises
          .map((re) => re.toWorkoutExercise())
          .toList();

      _activeWorkout = Workout(
        name: routine.name,
        startTime: DateTime.now(),
        exercises: workoutExercises,
        routineId: routine.id,
      );

      await _db.insertWorkout(_activeWorkout!);
      await _db.incrementRoutineUsage(routine.id);
      _error = null;
    } catch (e) {
      _error = 'Failed to start workout from routine: $e';
      _activeWorkout = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add an exercise to the active workout
  Future<void> addExercise(Exercise exercise) async {
    if (_activeWorkout == null) {
      _error = 'No active workout';
      notifyListeners();
      return;
    }

    try {
      final workoutExercise = WorkoutExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        order: _activeWorkout!.exercises.length,
        sets: [WorkoutSet(setNumber: 1)],
      );

      final updatedExercises = [..._activeWorkout!.exercises, workoutExercise];

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to add exercise: $e';
    }

    notifyListeners();
  }

  /// Remove an exercise from the active workout
  Future<void> removeExercise(int index) async {
    if (_activeWorkout == null || index >= _activeWorkout!.exercises.length) {
      return;
    }

    try {
      final updatedExercises = List<WorkoutExercise>.from(
        _activeWorkout!.exercises,
      );
      updatedExercises.removeAt(index);

      // Re-order remaining exercises
      for (int i = 0; i < updatedExercises.length; i++) {
        updatedExercises[i] = updatedExercises[i].copyWith(order: i);
      }

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to remove exercise: $e';
    }

    notifyListeners();
  }

  /// Reorder exercises
  Future<void> reorderExercise(int oldIndex, int newIndex, {bool isAdjusted = true}) async {
    if (_activeWorkout == null) return;

    try {
      final updatedExercises = List<WorkoutExercise>.from(
        _activeWorkout!.exercises,
      );

      if (!isAdjusted && newIndex > oldIndex) newIndex -= 1;
      final exercise = updatedExercises.removeAt(oldIndex);
      updatedExercises.insert(newIndex, exercise);

      // Re-order all exercises
      for (int i = 0; i < updatedExercises.length; i++) {
        updatedExercises[i] = updatedExercises[i].copyWith(order: i);
      }

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to reorder exercise: $e';
    }

    notifyListeners();
  }

  /// Add a set to an exercise
  Future<void> addSet(int exerciseIndex) async {
    if (_activeWorkout == null ||
        exerciseIndex >= _activeWorkout!.exercises.length) {
      return;
    }

    try {
      final exercise = _activeWorkout!.exercises[exerciseIndex];
      final lastSet = exercise.sets.isNotEmpty ? exercise.sets.last : null;

      final newSet = WorkoutSet(
        setNumber: exercise.sets.length + 1,
        weight: lastSet?.weight,
        reps: lastSet?.reps,
      );

      final updatedSets = [...exercise.sets, newSet];
      final updatedExercise = exercise.copyWith(sets: updatedSets);

      final updatedExercises = List<WorkoutExercise>.from(
        _activeWorkout!.exercises,
      );
      updatedExercises[exerciseIndex] = updatedExercise;

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to add set: $e';
    }

    notifyListeners();
  }

  /// Remove a set from an exercise
  Future<void> removeSet(int exerciseIndex, int setIndex) async {
    if (_activeWorkout == null ||
        exerciseIndex >= _activeWorkout!.exercises.length) {
      return;
    }

    try {
      final exercise = _activeWorkout!.exercises[exerciseIndex];
      if (setIndex >= exercise.sets.length) return;

      final updatedSets = List<WorkoutSet>.from(exercise.sets);
      updatedSets.removeAt(setIndex);

      // Re-number sets
      for (int i = 0; i < updatedSets.length; i++) {
        updatedSets[i] = updatedSets[i].copyWith(setNumber: i + 1);
      }

      final updatedExercise = exercise.copyWith(sets: updatedSets);

      final updatedExercises = List<WorkoutExercise>.from(
        _activeWorkout!.exercises,
      );
      updatedExercises[exerciseIndex] = updatedExercise;

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to remove set: $e';
    }

    notifyListeners();
  }

  /// Update a set's values
  Future<void> updateSet(
    int exerciseIndex,
    int setIndex, {
    double? weight,
    int? reps,
    double? duration,
    double? distance,
    bool? isWarmup,
    bool? isDropSet,
    bool? isFailure,
    bool? isCompleted,
  }) async {
    if (_activeWorkout == null ||
        exerciseIndex >= _activeWorkout!.exercises.length) {
      return;
    }

    try {
      final exercise = _activeWorkout!.exercises[exerciseIndex];
      if (setIndex >= exercise.sets.length) return;

      final set = exercise.sets[setIndex];
      final updatedSet = set.copyWith(
        weight: weight,
        reps: reps,
        duration: duration,
        distance: distance,
        isWarmup: isWarmup,
        isDropSet: isDropSet,
        isFailure: isFailure,
        isCompleted: isCompleted,
        completedAt: (isCompleted == true) ? DateTime.now() : null,
      );

      final updatedSets = List<WorkoutSet>.from(exercise.sets);
      updatedSets[setIndex] = updatedSet;

      final updatedExercise = exercise.copyWith(sets: updatedSets);

      final updatedExercises = List<WorkoutExercise>.from(
        _activeWorkout!.exercises,
      );
      updatedExercises[exerciseIndex] = updatedExercise;

      _activeWorkout = _activeWorkout!.copyWith(exercises: updatedExercises);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;

      // Check for new PRs if set was completed
      if (isCompleted == true) {
        await _checkForPRs(exercise, updatedSet);
      }
    } catch (e) {
      _error = 'Failed to update set: $e';
    }

    notifyListeners();
  }

  /// Toggle set completion
  Future<void> toggleSetCompleted(int exerciseIndex, int setIndex) async {
    if (_activeWorkout == null ||
        exerciseIndex >= _activeWorkout!.exercises.length) {
      return;
    }

    final exercise = _activeWorkout!.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final set = exercise.sets[setIndex];
    await updateSet(exerciseIndex, setIndex, isCompleted: !set.isCompleted);
  }

  /// Check for personal records
  Future<void> _checkForPRs(WorkoutExercise exercise, WorkoutSet set) async {
    if (set.weight == null || set.reps == null) return;
    if (set.weight! <= 0 || set.reps! <= 0) return;

    try {
      // Check for max weight PR
      final currentMaxWeight = await _db.getBestPRForExercise(
        exercise.exerciseId,
        PRType.maxWeight,
      );

      if (currentMaxWeight == null || set.weight! > currentMaxWeight.value) {
        final pr = PersonalRecord(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          type: PRType.maxWeight,
          value: set.weight!,
          workoutId: _activeWorkout?.id,
          setId: set.id,
        );
        await _db.insertPersonalRecord(pr);
      }

      // Check for max volume PR
      final volume = set.weight! * set.reps!;
      final currentMaxVolume = await _db.getBestPRForExercise(
        exercise.exerciseId,
        PRType.maxVolume,
      );

      if (currentMaxVolume == null || volume > currentMaxVolume.value) {
        final pr = PersonalRecord(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          type: PRType.maxVolume,
          value: volume,
          workoutId: _activeWorkout?.id,
          setId: set.id,
        );
        await _db.insertPersonalRecord(pr);
      }

      // Calculate and check estimated 1RM
      final estimated1RM = OneRepMaxCalculator.calculate(
        set.weight!,
        set.reps!,
      );
      final current1RM = await _db.getBestPRForExercise(
        exercise.exerciseId,
        PRType.oneRepMax,
      );

      if (current1RM == null || estimated1RM > current1RM.value) {
        final pr = PersonalRecord(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          type: PRType.oneRepMax,
          value: estimated1RM,
          workoutId: _activeWorkout?.id,
          setId: set.id,
        );
        await _db.insertPersonalRecord(pr);
      }
    } catch (e) {
      debugPrint('Error checking PRs: $e');
    }
  }

  /// Update workout name
  Future<void> updateWorkoutName(String name) async {
    if (_activeWorkout == null) return;

    try {
      _activeWorkout = _activeWorkout!.copyWith(name: name);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to update workout name: $e';
    }

    notifyListeners();
  }

  /// Update workout notes
  Future<void> updateWorkoutNotes(String notes) async {
    if (_activeWorkout == null) return;

    try {
      _activeWorkout = _activeWorkout!.copyWith(notes: notes);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to update workout notes: $e';
    }

    notifyListeners();
  }

  /// Add paused/idle duration to the active workout
  Future<void> addPausedDuration(Duration pausedDuration) async {
    if (_activeWorkout == null || pausedDuration.inSeconds <= 0) return;

    try {
      final updatedPausedSeconds =
          _activeWorkout!.pausedSeconds + pausedDuration.inSeconds;
      _activeWorkout =
          _activeWorkout!.copyWith(pausedSeconds: updatedPausedSeconds);
      await _db.updateWorkout(_activeWorkout!);
      _error = null;
    } catch (e) {
      _error = 'Failed to update paused duration: $e';
    }

    notifyListeners();
  }

  /// Finish the active workout
  Future<Workout?> finishWorkout() async {
    if (_activeWorkout == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final finishedWorkout = _activeWorkout!.copyWith(endTime: DateTime.now());

      await _db.updateWorkout(finishedWorkout);
      _activeWorkout = null;
      _error = null;

      _isLoading = false;
      notifyListeners();

      return finishedWorkout;
    } catch (e) {
      _error = 'Failed to finish workout: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cancel/discard the active workout
  Future<void> cancelWorkout() async {
    if (_activeWorkout == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.deleteWorkout(_activeWorkout!.id);
      _activeWorkout = null;
      _error = null;
    } catch (e) {
      _error = 'Failed to cancel workout: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear any error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
