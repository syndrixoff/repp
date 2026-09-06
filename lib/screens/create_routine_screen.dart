import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/routine_provider.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import '../widgets/set_type_bottom_sheet.dart';
import 'exercise_picker_screen.dart';
import 'exercise_detail_screen.dart';

class CreateRoutineScreen extends StatefulWidget {
  final Routine? routine;

  const CreateRoutineScreen({super.key, this.routine});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> _allWeekdays = [1, 2, 3, 4, 5, 6, 7];
  static const Map<int, String> _weekdayLabel = {
    1: 'MON',
    2: 'TUE',
    3: 'WED',
    4: 'THU',
    5: 'FRI',
    6: 'SAT',
    7: 'SUN',
  };

  final TextEditingController _nameController = TextEditingController();
  List<_EditableExercise> _exercises = [];
  List<int> _selectedWeekdays = List<int>.from(_allWeekdays);
  bool _isLoading = false;
  bool _isReordering = false;
  late AnimationController _emptyStateController;
  late Animation<double> _emptyStateFade;

  bool get isEditing => widget.routine != null;

  @override
  void initState() {
    super.initState();

    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _emptyStateFade = CurvedAnimation(
      parent: _emptyStateController,
      curve: Curves.easeOut,
    );
    _emptyStateController.forward();

    // Keep UI responsive to changes in the title so Save/Update button enables/disables.
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _selectedWeekdays = List<int>.from(widget.routine!.scheduledWeekdays);
      _exercises = widget.routine!.exercises.map((ex) {
        final types = ex.setTypes?.split(',') ?? [];
        return _EditableExercise(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          notes: ex.notes ?? '',
          restTimerEnabled: false,
          sets: List.generate(ex.targetSets, (i) {
            final type = i < types.length ? types[i] : 'N';
            return _EditableSet(
              weight: ex.targetWeight,
              reps: ex.targetReps,
              duration: ex.targetDuration,
              isWarmup: type == 'W',
              isDropSet: type == 'D',
              isFailure: type == 'F',
            );
          }),
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Shows a discard confirmation dialog and returns true if the user wants to leave.
  Future<bool> _onWillPop() async {
    // If user didn't type a title and no exercises added, just pop normally
    if (_nameController.text.trim().isEmpty && _exercises.isEmpty) return true;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
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
                      Icons.delete_sweep_outlined,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Discard Routine?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your unsaved changes will be lost.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
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
                        'Discard',
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
                      onPressed: () => Navigator.of(context).pop(false),
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
                        'Keep Editing',
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
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final shouldLeave = await _onWillPop();
              if (shouldLeave && mounted) nav.pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 15,
              ),
            ),
          ),
          leadingWidth: 80,
          title: Text(
            isEditing ? 'Edit Routine' : 'New Routine',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        key: ValueKey(
                          _nameController.text.trim().isEmpty ||
                              _exercises.isEmpty,
                        ),
                        onPressed:
                            (_nameController.text.trim().isEmpty ||
                                _exercises.isEmpty)
                            ? null
                            : _saveRoutine,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          disabledForegroundColor: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade500,
                        ),
                        child: Text(
                          isEditing ? 'Update' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Routine title input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Routine title',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedWeekdays = List<int>.from(_allWeekdays);
                          });
                        },
                        child: const Text('Every day'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allWeekdays.map((weekday) {
                      final selected = _selectedWeekdays.contains(weekday);
                      return FilterChip(
                        label: Text(_weekdayLabel[weekday]!),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedWeekdays = {
                                ..._selectedWeekdays,
                                weekday,
                              }.toList()..sort();
                            } else {
                              _selectedWeekdays = _selectedWeekdays
                                  .where((d) => d != weekday)
                                  .toList();
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_isReordering) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reorder mode active',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setState(() {
                              _isReordering = false;
                            });
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Apply Order'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isReordering
                      ? colorScheme.primary.withValues(alpha: 0.14)
                      : colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isReordering
                          ? Icons.swap_vert_rounded
                          : Icons.touch_app_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isReordering
                            ? 'Reorder mode active: drag items, then tap Apply Order.'
                            : 'Tip: long press any exercise card to reorder.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Exercises list (empty-state vs list)
            Expanded(
              child: _exercises.isEmpty
                  ? FadeTransition(
                      opacity: _emptyStateFade,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.fitness_center_rounded,
                                          size: 48,
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Start building your routine',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add exercises to create your perfect workout routine.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade600,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _addExercise,
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 22,
                                          ),
                                          label: const Text(
                                            'Add Exercise',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            backgroundColor:
                                                colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) {
                            return Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.96,
                                child: _CompactExerciseTile(
                                  exerciseId: _exercises[index].exerciseId,
                                  exerciseName: _exercises[index].exerciseName,
                                  showDragHandle: true,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      itemCount: _exercises.length,
                      onReorderStart: (startIndex) {
                        if (!_isReordering) {
                          setState(() {
                            _isReordering = true;
                          });
                        }
                      },
                      onReorderEnd: (endIndex) {},
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final moved = _exercises.removeAt(oldIndex);
                          _exercises.insert(newIndex, moved);
                        });
                      },
                      itemBuilder: (context, index) {
                        final exercise = _exercises[index];
                        final card = _ExerciseCard(
                          exercise: exercise,
                          compactMode: _isReordering,
                          onUpdate: (updated) {
                            setState(() {
                              _exercises[index] = updated;
                            });
                          },
                          onDelete: () => _deleteExercise(index),
                          onViewDetails: () => _viewExerciseDetails(exercise),
                        );

                        if (!_isReordering) {
                          return GestureDetector(
                            key: ValueKey(exercise.itemKey),
                            behavior: HitTestBehavior.translucent,
                            onLongPress: () {
                              setState(() {
                                _isReordering = true;
                              });
                            },
                            child: card,
                          );
                        }

                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(exercise.itemKey),
                          index: index,
                          child: card,
                        );
                      },
                    ),
            ),
          ],
        ),
        // Bottom Add Exercise button when exercises exist
        bottomNavigationBar: _exercises.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add Exercise',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _addExercise() async {
    final exercises = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => const ExercisePickerScreen(multiSelect: true),
      ),
    );

    if (exercises != null && exercises.isNotEmpty) {
      setState(() {
        _exercises.addAll(
          exercises.map(
            (exercise) => _EditableExercise(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              notes: '',
              restTimerEnabled: false,
              sets: [_EditableSet()],
            ),
          ),
        );
      });
    }
  }

  void _deleteExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _viewExerciseDetails(_EditableExercise editableExercise) {
    final svc = ExerciseService();
    final exercise = svc.getById(editableExercise.exerciseId);
    if (exercise != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseDetailScreen(exerciseId: exercise.id),
        ),
      );
    }
  }

  Future<void> _saveRoutine() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a routine name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Select at least one day for this routine'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final routineProvider = context.read<RoutineProvider>();

    try {
      // Convert editable exercises to RoutineExercise
      final routineExercises = _exercises.asMap().entries.map((entry) {
        final index = entry.key;
        final ex = entry.value;
        final firstSet = ex.sets.isNotEmpty ? ex.sets.first : null;

        final setTypes = ex.sets
            .map((s) {
              if (s.isWarmup) return 'W';
              if (s.isDropSet) return 'D';
              if (s.isFailure) return 'F';
              return 'N';
            })
            .join(',');

        return RoutineExercise(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          order: index,
          targetSets: ex.sets.length,
          targetReps: firstSet?.reps,
          targetWeight: firstSet?.weight,
          targetDuration: firstSet?.duration,
          notes: ex.notes.isNotEmpty ? ex.notes : null,
          setTypes: setTypes,
        );
      }).toList();

      if (isEditing) {
        final updated = widget.routine!.copyWith(
          name: _nameController.text.trim(),
          exercises: routineExercises,
          scheduledWeekdays: _selectedWeekdays,
        );
        await routineProvider.updateRoutine(updated);
      } else {
        await routineProvider.createRoutine(
          name: _nameController.text.trim(),
          exercises: routineExercises,
          scheduledWeekdays: _selectedWeekdays,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save routine: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Editable exercise model for the form
class _EditableExercise {
  final String itemKey;
  final String exerciseId;
  final String exerciseName;
  String notes;
  bool restTimerEnabled;
  List<_EditableSet> sets;

  _EditableExercise({
    String? itemKey,
    required this.exerciseId,
    required this.exerciseName,
    required this.notes,
    required this.restTimerEnabled,
    required this.sets,
  }) : itemKey = itemKey ?? UniqueKey().toString();

  _EditableExercise copyWith({
    String? itemKey,
    String? exerciseId,
    String? exerciseName,
    String? notes,
    bool? restTimerEnabled,
    List<_EditableSet>? sets,
  }) {
    return _EditableExercise(
      itemKey: itemKey ?? this.itemKey,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      notes: notes ?? this.notes,
      restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
      sets: sets ?? this.sets,
    );
  }
}

class _EditableSet {
  double? weight;
  int? reps;
  double? duration; // in seconds
  double? distance; // in meters
  bool isWarmup;
  bool isDropSet;
  bool isFailure;

  _EditableSet({
    this.weight,
    this.reps,
    this.duration,
    this.distance,
    this.isWarmup = false,
    this.isDropSet = false,
    this.isFailure = false,
  });
}

class _CompactExerciseTile extends StatelessWidget {
  final String exerciseId;
  final String exerciseName;
  final bool showDragHandle;
  final bool wrapInContainer;

  const _CompactExerciseTile({
    required this.exerciseId,
    required this.exerciseName,
    this.showDragHandle = true,
    this.wrapInContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ex = ExerciseService().getById(exerciseId);
    final thumbnailUrl = ex?.thumbnailUrl;

    final row = Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
            clipBehavior: Clip.antiAlias,
            child: thumbnailUrl != null
                ? Image.asset(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.fitness_center,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  )
                : Icon(
                    Icons.fitness_center,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exerciseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          if (showDragHandle)
            Icon(
              Icons.drag_indicator,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
        ],
      );

    if (!wrapInContainer) return row;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: row,
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final _EditableExercise exercise;
  final bool compactMode;
  final Function(_EditableExercise) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const _ExerciseCard({
    required this.exercise,
    required this.compactMode,
    required this.onUpdate,
    required this.onDelete,
    required this.onViewDetails,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late TextEditingController _notesController;
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _distanceControllers = {};

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.exercise.notes);
    _initSetControllers();
  }

  void _initSetControllers() {
    _weightControllers.clear();
    _repsControllers.clear();
    _durationControllers.clear();
    _distanceControllers.clear();
    for (int i = 0; i < widget.exercise.sets.length; i++) {
      final set = widget.exercise.sets[i];
      _weightControllers['$i'] = TextEditingController(
        text: set.weight?.toString() ?? '',
      );
      _repsControllers['$i'] = TextEditingController(
        text: set.reps?.toString() ?? '',
      );
      _durationControllers['$i'] = TextEditingController(
        text: set.duration != null
            ? (set.duration! / 60).toStringAsFixed(0)
            : '',
      );
      _distanceControllers['$i'] = TextEditingController(
        text: set.distance != null
            ? (set.distance! / 1000).toStringAsFixed(2)
            : '',
      );
    }
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.sets.length != widget.exercise.sets.length) {
      _initSetControllers();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    for (final c in _repsControllers.values) {
      c.dispose();
    }
    for (final c in _durationControllers.values) {
      c.dispose();
    }
    for (final c in _distanceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ExerciseService();
    final ex = svc.getById(widget.exercise.exerciseId);
    final thumbnailUrl = ex?.thumbnailUrl;
    final equipment = ex?.equipment ?? 'Other';
    final showWeight = EquipmentType.needsWeight(equipment);
    final primaryMuscle = ex?.primaryMuscle ?? 'Other';
    final isCardio = CardioType.isCardio(primaryMuscle);
    final needsDistance = ex != null && CardioType.needsDistance(ex.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        child: widget.compactMode
            ? _CompactExerciseTile(
                exerciseId: widget.exercise.exerciseId,
                exerciseName: widget.exercise.exerciseName,
                wrapInContainer: false,
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with thumbnail, name, and menu
            Row(
              children: [
                // Thumbnail
                GestureDetector(
                  onTap: widget.onViewDetails,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: thumbnailUrl != null
                        ? Image.asset(
                            thumbnailUrl,
                            key: ValueKey(thumbnailUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.fitness_center,
                              color: Colors.grey.shade500,
                              size: 22,
                            ),
                          )
                        : Icon(
                            Icons.fitness_center,
                            color: Colors.grey.shade500,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Exercise name (tappable)
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onViewDetails,
                    child: Text(
                      widget.exercise.exerciseName,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                // Menu button
                _ExerciseMenuButton(
                  onDelete: widget.onDelete,
                  onViewDetails: widget.onViewDetails,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Notes field
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add routine notes...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade100,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              onChanged: (value) {
                widget.onUpdate(widget.exercise.copyWith(notes: value));
              },
            ),

            // Rest Timer toggle
            GestureDetector(
              onTap: () {
                widget.onUpdate(
                  widget.exercise.copyWith(
                    restTimerEnabled: !widget.exercise.restTimerEnabled,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: widget.exercise.restTimerEnabled
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: widget.exercise.restTimerEnabled
                          ? colorScheme.primary
                          : (isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rest Timer: ${widget.exercise.restTimerEnabled ? "ON" : "OFF"}',
                      style: TextStyle(
                        color: widget.exercise.restTimerEnabled
                            ? colorScheme.primary
                            : (isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Sets header
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

            // Sets list
            ...widget.exercise.sets.asMap().entries.map((entry) {
              final setIndex = entry.key;
              final set = entry.value;

              final setTypeLabel = set.isWarmup
                  ? 'W'
                  : set.isDropSet
                  ? 'D'
                  : set.isFailure
                  ? 'F'
                  : '${setIndex + 1}';

              final setColor = set.isWarmup
                  ? Colors.orange
                  : set.isDropSet
                  ? Colors.blue
                  : set.isFailure
                  ? AppColors.error
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    // Set type badge
                    GestureDetector(
                      onTap: () async {
                        final option = await SetTypeBottomSheet.show(
                          context,
                          setIndex + 1,
                        );
                        if (option != null) {
                          final newSets = List<_EditableSet>.from(
                            widget.exercise.sets,
                          );
                          if (option == SetTypeOption.remove) {
                            newSets.removeAt(setIndex);
                          } else {
                            newSets[setIndex] = _EditableSet(
                              weight: set.weight,
                              reps: set.reps,
                              isWarmup: option == SetTypeOption.warmUp,
                              isDropSet: option == SetTypeOption.drop,
                              isFailure: option == SetTypeOption.failure,
                            );
                          }
                          widget.onUpdate(
                            widget.exercise.copyWith(sets: newSets),
                          );
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
                                (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Weight / Distance input
                    if (isCardio && needsDistance) ...[
                      Expanded(
                        child: _SetInputField(
                          controller: _distanceControllers['$setIndex'],
                          isDark: isDark,
                          isDecimal: true,
                          onChanged: (value) {
                            final newSets = List<_EditableSet>.from(
                              widget.exercise.sets,
                            );
                            final km = double.tryParse(value);
                            newSets[setIndex].distance = km != null
                                ? km * 1000
                                : null;
                            widget.onUpdate(
                              widget.exercise.copyWith(sets: newSets),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (!isCardio && showWeight) ...[
                      Expanded(
                        child: _SetInputField(
                          controller: _weightControllers['$setIndex'],
                          isDark: isDark,
                          isDecimal: true,
                          onChanged: (value) {
                            final newSets = List<_EditableSet>.from(
                              widget.exercise.sets,
                            );
                            newSets[setIndex].weight = double.tryParse(value);
                            widget.onUpdate(
                              widget.exercise.copyWith(sets: newSets),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Reps / Duration input
                    if (isCardio)
                      Expanded(
                        child: _SetInputField(
                          controller: _durationControllers['$setIndex'],
                          isDark: isDark,
                          isDecimal: true,
                          onChanged: (value) {
                            final newSets = List<_EditableSet>.from(
                              widget.exercise.sets,
                            );
                            final mins = double.tryParse(value);
                            newSets[setIndex].duration = mins != null
                                ? mins * 60
                                : null;
                            widget.onUpdate(
                              widget.exercise.copyWith(sets: newSets),
                            );
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: _SetInputField(
                          controller: _repsControllers['$setIndex'],
                          isDark: isDark,
                          isDecimal: false,
                          onChanged: (value) {
                            final newSets = List<_EditableSet>.from(
                              widget.exercise.sets,
                            );
                            newSets[setIndex].reps = int.tryParse(value);
                            widget.onUpdate(
                              widget.exercise.copyWith(sets: newSets),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),

            // Add Set button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  final newSets = List<_EditableSet>.from(widget.exercise.sets);
                  // Copy values from last set if exists
                  final lastSet = newSets.isNotEmpty ? newSets.last : null;
                  newSets.add(
                    _EditableSet(
                      weight: lastSet?.weight,
                      reps: lastSet?.reps,
                      duration: lastSet?.duration,
                      distance: lastSet?.distance,
                    ),
                  );
                  widget.onUpdate(widget.exercise.copyWith(sets: newSets));
                },
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

class _SetInputField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isDark;
  final bool isDecimal;
  final ValueChanged<String> onChanged;

  const _SetInputField({
    required this.controller,
    required this.isDark,
    required this.isDecimal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '-',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          isDense: true,
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: onChanged,
      ),
    );
  }
}

class _ExerciseMenuButton extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;
  final bool isDark;

  const _ExerciseMenuButton({
    required this.onDelete,
    required this.onViewDetails,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 22,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      onSelected: (value) {
        if (value == 'delete') {
          onDelete();
        } else if (value == 'view') {
          onViewDetails();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 10),
              const Text('View Exercise'),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: 10),
              Text('Remove', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
