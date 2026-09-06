import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../providers/history_provider.dart';
import '../providers/player_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../models/models.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import '../widgets/set_type_bottom_sheet.dart';
import 'exercise_picker_screen.dart';
import 'exercise_detail_screen.dart';
import 'workout_complete_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout != null) {
      _nameController.text = workout.name;
    }
    // Live timer — rebuild every second so duration ticks
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final workout = workoutProvider.activeWorkout;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (workout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: _isEditingName
            ? TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Workout Name',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onSubmitted: (value) {
                  workoutProvider.updateWorkoutName(value);
                  setState(() => _isEditingName = false);
                },
              )
            : GestureDetector(
                onTap: () => setState(() => _isEditingName = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        workout.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => _showFinishDialog(context, workoutProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Finish',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer and stats bar
          _WorkoutStatsBar(workout: workout, isDark: isDark),

          // Exercises list
          Expanded(
            child: workout.exercises.isEmpty
                ? _EmptyWorkoutView(
                    onAddExercise: () => _addExercise(context, workoutProvider),
                    isDark: isDark,
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: workout.exercises.length + 1,
                    onReorderItem: (oldIndex, newIndex) {
                      if (oldIndex < workout.exercises.length &&
                          newIndex < workout.exercises.length) {
                        workoutProvider.reorderExercise(oldIndex, newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      if (index == workout.exercises.length) {
                        return Padding(
                          key: const ValueKey('add_exercise'),
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _addExercise(context, workoutProvider),
                            icon: Icon(
                              Icons.add_rounded,
                              color: colorScheme.primary,
                            ),
                            label: Text(
                              'Add Exercise',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: colorScheme.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        );
                      }

                      final exercise = workout.exercises[index];
                      return _ExerciseCard(
                        key: ValueKey(exercise.id),
                        exercise: exercise,
                        exerciseIndex: index,
                        workoutProvider: workoutProvider,
                        isDark: isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context, workoutProvider),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addExercise(context, workoutProvider),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add Exercise',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addExercise(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) async {
    final exercise = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (context) => const ExercisePickerScreen()),
    );

    if (exercise != null) {
      await workoutProvider.addExercise(exercise);
    }
  }

  void _showFinishDialog(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    final workout = workoutProvider.activeWorkout;
    if (workout == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Finish Workout?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _FinishDialogStat(
                        icon: Icons.timer_rounded,
                        label: 'Duration',
                        value: workout.durationString,
                        color: AppColors.accentOrange,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _FinishDialogStat(
                        icon: Icons.fitness_center_rounded,
                        label: 'Exercises',
                        value: '${workout.exercises.length}',
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _FinishDialogStat(
                        icon: Icons.check_circle_rounded,
                        label: 'Sets Completed',
                        value: '${workout.completedSets}/${workout.totalSets}',
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                      if (workout.totalVolume > 0) ...[
                        const SizedBox(height: 10),
                        _FinishDialogStat(
                          icon: Icons.trending_up_rounded,
                          label: 'Total Volume',
                          value: '${workout.totalVolume.toStringAsFixed(0)} kg',
                          color: AppColors.accentPurple,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Capture workout before finishing
                      final completedWorkout = workoutProvider.activeWorkout;
                      Navigator.pop(context);
                      await workoutProvider.finishWorkout();
                      if (context.mounted) {
                        final historyProvider = context.read<HistoryProvider>();
                        final playerProvider = context.read<PlayerProvider>();
                        final questProvider = context.read<DailyQuestProvider>();
                        await historyProvider.refresh();
                        // Award XP and show reward screen
                        if (completedWorkout != null) {
                          final xpResult = await playerProvider.awardWorkoutXP(
                            completedWorkout,
                          );
                          await questProvider.registerProgressMilestones(
                            xpResult: xpResult,
                            stats: playerProvider.stats,
                          );
                          await questProvider.ensureToday(
                            stats: playerProvider.stats,
                            workoutHistory: historyProvider.workoutHistory,
                          );
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutCompleteScreen(
                                  xpResult: xpResult,
                                  workout: completedWorkout,
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Finish Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep Going',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Cancel Workout?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All progress from this workout will be lost.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await workoutProvider.cancelWorkout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cancel Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep Going',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishDialogStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _FinishDialogStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _WorkoutStatsBar extends StatelessWidget {
  final Workout workout;
  final bool isDark;

  const _WorkoutStatsBar({required this.workout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsBarItem(
              label: 'Duration',
              value: workout.durationString,
              icon: Icons.timer_rounded,
              color: AppColors.accentOrange,
              isDark: isDark,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          Expanded(
            child: _StatsBarItem(
              label: 'Volume',
              value: '${workout.totalVolume.toStringAsFixed(0)} kg',
              icon: Icons.fitness_center_rounded,
              color: AppColors.primary,
              isDark: isDark,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          Expanded(
            child: _StatsBarItem(
              label: 'Sets',
              value: '${workout.completedSets}/${workout.totalSets}',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBarItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatsBarItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _EmptyWorkoutView extends StatelessWidget {
  final VoidCallback onAddExercise;
  final bool isDark;

  const _EmptyWorkoutView({required this.onAddExercise, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No exercises yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add an exercise to start\ntracking your workout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Add Exercise',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutExercise exercise;
  final int exerciseIndex;
  final WorkoutProvider workoutProvider;
  final bool isDark;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.exerciseIndex,
    required this.workoutProvider,
    required this.isDark,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  List<Map<String, dynamic>> _previousSets = [];
  bool _loadedPrevious = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousSets();
  }

  Future<void> _loadPreviousSets() async {
    final historyProvider = context.read<HistoryProvider>();
    final history = await historyProvider.getExerciseHistory(
      widget.exercise.exerciseId,
    );

    if (history.isNotEmpty && mounted) {
      // Group by workout_id and get the most recent workout's sets
      final Map<String, List<Map<String, dynamic>>> byWorkout = {};
      for (final row in history) {
        final wid = row['workout_id'].toString();
        byWorkout.putIfAbsent(wid, () => []);
        byWorkout[wid]!.add(row);
      }

      // The history is ordered by start_time DESC, so first workout is most recent
      if (byWorkout.isNotEmpty) {
        final firstWorkoutId = byWorkout.keys.first;
        setState(() {
          _previousSets = byWorkout[firstWorkoutId]!;
          _loadedPrevious = true;
        });
      } else {
        setState(() => _loadedPrevious = true);
      }
    } else {
      if (mounted) setState(() => _loadedPrevious = true);
    }
  }

  /// Get the "previous" value for a given set index.
  Map<String, dynamic>? _getPreviousForSet(int setIndex) {
    if (!_loadedPrevious || _previousSets.isEmpty) return null;
    if (setIndex >= _previousSets.length) return null;

    return _previousSets[setIndex];
  }

  /// Look up equipment for this exercise from the ExerciseService.
  String _getEquipment() {
    final svc = ExerciseService();
    final ex = svc.getById(widget.exercise.exerciseId);
    return ex?.equipment ?? 'Other';
  }

  void _showExerciseOptions(BuildContext context) {
    final isDark = widget.isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.info_outline_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: const Text('View Exercise Details'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                final svc = ExerciseService();
                final ex = svc.getById(widget.exercise.exerciseId);
                if (ex != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ExerciseDetailScreen(exerciseId: ex.id),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'Remove Exercise',
                style: TextStyle(color: AppColors.error),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.workoutProvider.removeExercise(widget.exerciseIndex);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipment = _getEquipment();
    final showWeight = EquipmentType.needsWeight(equipment);
    final isDark = widget.isDark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.drag_handle_rounded,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exercise.exerciseName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (!showWeight)
                        Text(
                          equipment == 'None' ? 'Bodyweight' : equipment,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showExerciseOptions(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sets header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      'SET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PREVIOUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (showWeight)
                    Expanded(
                      child: Text(
                        'KG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey.shade500 : Colors.grey,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'REPS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: isDark ? Colors.grey.shade500 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Sets list
            ...widget.exercise.sets.asMap().entries.map((entry) {
              final setIndex = entry.key;
              final set = entry.value;
              return _SetRow(
                set: set,
                setIndex: setIndex,
                exerciseIndex: widget.exerciseIndex,
                workoutProvider: widget.workoutProvider,
                showWeight: showWeight,
                previousValue: _getPreviousForSet(setIndex),
                isDark: isDark,
              );
            }),

            // Add set button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    widget.workoutProvider.addSet(widget.exerciseIndex),
                icon: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                label: Text(
                  'Add Set',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final WorkoutSet set;
  final int setIndex;
  final int exerciseIndex;
  final WorkoutProvider workoutProvider;
  final bool showWeight;
  final Map<String, dynamic>? previousValue;
  final bool isDark;

  const _SetRow({
    required this.set,
    required this.setIndex,
    required this.exerciseIndex,
    required this.workoutProvider,
    required this.showWeight,
    required this.previousValue,
    required this.isDark,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.set.weight?.toStringAsFixed(1) ?? '',
    );
    _repsController = TextEditingController(
      text: widget.set.reps?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(_SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.weight != widget.set.weight) {
      _weightController.text = widget.set.weight?.toStringAsFixed(1) ?? '';
    }
    if (oldWidget.set.reps != widget.set.reps) {
      _repsController.text = widget.set.reps?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Widget _buildPreviousValue() {
    final prev = widget.previousValue;
    if (prev == null) {
      return Text(
        '-',
        style: TextStyle(
          color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          fontSize: 13,
        ),
      );
    }

    final weight = prev['weight'];
    final reps = prev['reps'];
    final duration = prev['duration'];

    if (duration != null && duration > 0) {
      return Text(
        '${(duration as num).toStringAsFixed(0)}s',
        style: TextStyle(
          color: widget.isDark ? Colors.grey.shade500 : Colors.grey.shade500,
          fontSize: 13,
        ),
      );
    }

    if (weight != null && reps != null) {
      final w = weight is num ? weight : num.tryParse(weight.toString()) ?? 0;
      final weightStr = w == w.toInt()
          ? '${w.toInt()} kg'
          : '${w.toStringAsFixed(1)} kg';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weightStr,
            style: TextStyle(
              color: widget.isDark
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '$reps reps',
            style: TextStyle(
              color: widget.isDark
                  ? Colors.grey.shade500
                  : Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    if (reps != null) {
      return Text(
        '$reps reps',
        style: TextStyle(
          color: widget.isDark ? Colors.grey.shade500 : Colors.grey.shade500,
          fontSize: 13,
        ),
      );
    }

    return Text(
      '-',
      style: TextStyle(
        color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.set.isCompleted;
    final isDark = widget.isDark;

    final setTypeLabel = widget.set.isWarmup
        ? 'W'
        : widget.set.isDropSet
        ? 'D'
        : widget.set.isFailure
        ? 'F'
        : '${widget.set.setNumber}';

    final setColor = widget.set.isWarmup
        ? Colors.orange
        : widget.set.isDropSet
        ? Colors.blue
        : widget.set.isFailure
        ? AppColors.error
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: isDark ? 0.08 : 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Set number / type badge
          GestureDetector(
            onTap: () async {
              final option = await SetTypeBottomSheet.show(
                context,
                widget.set.setNumber,
              );
              if (option != null) {
                if (option == SetTypeOption.remove) {
                  widget.workoutProvider.removeSet(
                    widget.exerciseIndex,
                    widget.setIndex,
                  );
                } else {
                  widget.workoutProvider.updateSet(
                    widget.exerciseIndex,
                    widget.setIndex,
                    isWarmup: option == SetTypeOption.warmUp,
                    isDropSet: option == SetTypeOption.drop,
                    isFailure: option == SetTypeOption.failure,
                  );
                }
              }
            },
            child: Container(
              width: 44,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: setColor != null
                    ? setColor.withValues(alpha: 0.12)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                setTypeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color:
                      setColor ??
                      (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Previous value from history
          Expanded(child: _buildPreviousValue()),

          // Weight input — only if equipment needs weight
          if (widget.showWeight) ...[
            Expanded(
              child: _WorkoutSetInput(
                controller: _weightController,
                isDark: isDark,
                isDecimal: true,
                isCompleted: isCompleted,
                onChanged: (value) {
                  final weight = double.tryParse(value);
                  widget.workoutProvider.updateSet(
                    widget.exerciseIndex,
                    widget.setIndex,
                    weight: weight,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Reps input
          Expanded(
            child: _WorkoutSetInput(
              controller: _repsController,
              isDark: isDark,
              isDecimal: false,
              isCompleted: isCompleted,
              onChanged: (value) {
                final reps = int.tryParse(value);
                widget.workoutProvider.updateSet(
                  widget.exerciseIndex,
                  widget.setIndex,
                  reps: reps,
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Complete checkbox
          SizedBox(
            width: 44,
            child: GestureDetector(
              onTap: () {
                widget.workoutProvider.toggleSetCompleted(
                  widget.exerciseIndex,
                  widget.setIndex,
                );
              },
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCompleted
                      ? AppColors.success
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSetInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool isDecimal;
  final bool isCompleted;
  final ValueChanged<String> onChanged;

  const _WorkoutSetInput({
    required this.controller,
    required this.isDark,
    required this.isDecimal,
    required this.isCompleted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: '-',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          filled: true,
          fillColor: isCompleted
              ? (isDark
                    ? AppColors.success.withValues(alpha: 0.06)
                    : AppColors.success.withValues(alpha: 0.04))
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
