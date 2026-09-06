import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/routine_provider.dart';
import '../providers/workout_provider.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import 'exercise_detail_screen.dart';
import 'create_routine_screen.dart';
import 'guided_workout_screen.dart';

class ViewRoutineScreen extends StatefulWidget {
  final String routineId;

  const ViewRoutineScreen({super.key, required this.routineId});

  @override
  State<ViewRoutineScreen> createState() => _ViewRoutineScreenState();
}

class _ViewRoutineScreenState extends State<ViewRoutineScreen> {
  String _selectedStat = 'Volume';

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final routineProvider = context.watch<RoutineProvider>();
    final routine = routineProvider.getRoutineById(widget.routineId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (routine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Routine')),
        body: const Center(
          child: Text('This routine is no longer available.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Routine',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 22),
            onPressed: () {
              // TODO: Share routine
            },
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with routine name and creator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Routine icon + name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 24,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (routine.exercises.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${routine.exercises.length} exercise${routine.exercises.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (routine.description != null &&
                      routine.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        routine.description!,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Start Routine Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await workoutProvider.startFromRoutine(routine);
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GuidedWorkoutScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'Start Routine',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsCard(isDark),
            ),

            const SizedBox(height: 16),

            // Stat type selector chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatChip('Volume', _selectedStat == 'Volume', isDark),
                  const SizedBox(width: 8),
                  _buildStatChip('Reps', _selectedStat == 'Reps', isDark),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Duration',
                    _selectedStat == 'Duration',
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Exercises header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _editRoutine(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Exercises list
            ...routine.exercises.map(
              (exercise) => _RoutineExerciseItem(
                exercise: exercise,
                isDark: isDark,
                onTap: () => _openExerciseDetail(context, exercise),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No data yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete this routine to see stats',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, bool isSelected, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStat = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade300,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                Icons.edit_outlined,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: const Text('Edit Routine'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                _editRoutine(context);
              },
            ),
            // Duplicate routine option removed
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'Delete Routine',
                style: TextStyle(color: AppColors.error),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Delete routine
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editRoutine(BuildContext context) {
    final routineProvider = context.read<RoutineProvider>();
    final latestRoutine = routineProvider.getRoutineById(widget.routineId);
    if (latestRoutine == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRoutineScreen(routine: latestRoutine),
      ),
    ).then((_) {
      // Refresh if needed
      if (mounted) setState(() {});
    });
  }

  void _openExerciseDetail(BuildContext context, RoutineExercise routineEx) {
    final svc = ExerciseService();
    final exercise = svc.getById(routineEx.exerciseId);
    if (exercise != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseDetailScreen(exerciseId: exercise.id),
        ),
      );
    }
  }
}

class _RoutineExerciseItem extends StatelessWidget {
  final RoutineExercise exercise;
  final bool isDark;
  final VoidCallback onTap;

  const _RoutineExerciseItem({
    required this.exercise,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final svc = ExerciseService();
    final ex = svc.getById(exercise.exerciseId);
    final thumbnailUrl = ex?.thumbnailUrl;
    final equipment = ex?.equipment ?? 'Other';
    final showWeight = EquipmentType.needsWeight(equipment);
    final primaryMuscle = ex?.primaryMuscle ?? 'Other';
    final isCardio = CardioType.isCardio(primaryMuscle);
    final needsDistance = ex != null && CardioType.needsDistance(ex.name);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header with thumbnail and name
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumbnailUrl != null
                      ? Image.asset(
                          thumbnailUrl,
                          key: ValueKey(thumbnailUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.fitness_center_rounded,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                            size: 22,
                          ),
                        )
                      : Icon(
                          Icons.fitness_center_rounded,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                // Exercise name
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  size: 22,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sets table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 44,
                  child: Text(
                    'SET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isCardio && needsDistance)
                  const Expanded(
                    child: Text(
                      'KM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (!isCardio && showWeight)
                  const Expanded(
                    child: Text(
                      'KG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: Text(
                    isCardio ? 'TIME' : 'REPS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Sets rows
          ...List.generate(exercise.targetSets, (index) {
            final types = exercise.setTypes?.split(',') ?? [];
            final type = index < types.length ? types[index] : 'N';

            final setTypeLabel = type == 'W'
                ? 'W'
                : type == 'D'
                ? 'D'
                : type == 'F'
                ? 'F'
                : '${index + 1}';

            final setColor = type == 'W'
                ? Colors.orange
                : type == 'D'
                ? Colors.blue
                : type == 'F'
                ? AppColors.error
                : null;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  // Set type badge
                  Container(
                    width: 44,
                    height: 34,
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
                            (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                      ),
                    ),
                  ),
                  if (isCardio && needsDistance)
                    Expanded(
                      child: Text(
                        '-',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (!isCardio && showWeight)
                    Expanded(
                      child: Text(
                        exercise.targetWeight != null
                            ? exercise.targetWeight!.toStringAsFixed(
                                exercise.targetWeight! ==
                                        exercise.targetWeight!.toInt()
                                    ? 0
                                    : 1,
                              )
                            : '-',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      isCardio
                          ? (exercise.targetDuration != null
                              ? '${(exercise.targetDuration! / 60).toStringAsFixed(0)} min'
                              : '-')
                          : (exercise.targetReps?.toString() ?? '-'),
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
