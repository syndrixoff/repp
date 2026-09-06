import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import 'exercise_detail_screen.dart';

class ExercisesTab extends StatefulWidget {
  const ExercisesTab({super.key});

  @override
  State<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<ExercisesTab> {
  final ExerciseService _exerciseService = ExerciseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  List<Exercise> _filteredExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeExercises();
  }

  Future<void> _initializeExercises() async {
    setState(() {
      _isLoading = true;
    });

    // Ensure exercises are loaded
    if (!_exerciseService.isLoaded) {
      await _exerciseService.loadExercises();
    }

    _filterExercises();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterExercises() {
    setState(() {
      _filteredExercises = _exerciseService.search(
        _searchQuery,
        equipment: _selectedEquipment,
        muscle: _selectedMuscle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Exercises',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _filterExercises();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterExercises();
              },
            ),
          ),

          // Filter buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Equipment filter button
                Expanded(
                  child: _FilterButton(
                    label: _selectedEquipment ?? 'Equipment',
                    icon: Icons.fitness_center_rounded,
                    isActive: _selectedEquipment != null,
                    onTap: () => _showEquipmentFilter(context),
                    onClear: _selectedEquipment != null
                        ? () {
                            setState(() {
                              _selectedEquipment = null;
                            });
                            _filterExercises();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                // Muscle filter button
                Expanded(
                  child: _FilterButton(
                    label: _selectedMuscle ?? 'Muscle',
                    icon: Icons.accessibility_new_rounded,
                    isActive: _selectedMuscle != null,
                    onTap: () => _showMuscleFilter(context),
                    onClear: _selectedMuscle != null
                        ? () {
                            setState(() {
                              _selectedMuscle = null;
                            });
                            _filterExercises();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Results count and clear filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isLoading
                      ? 'Loading...'
                      : '${_filteredExercises.length} exercises',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                if (_selectedMuscle != null || _selectedEquipment != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMuscle = null;
                        _selectedEquipment = null;
                      });
                      _filterExercises();
                    },
                    child: Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Exercise list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExercises.isEmpty
                ? _EmptyView(searchQuery: _searchQuery, isDark: isDark)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _filteredExercises.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 84,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.grey.shade100,
                    ),
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      return _ExerciseListTile(
                        exercise: exercise,
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExerciseDetailScreen(exerciseId: exercise.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEquipmentFilter(BuildContext context) {
    final equipmentTypes = _exerciseService.getEquipmentTypes();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Equipment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: equipmentTypes.length,
                  itemBuilder: (context, index) {
                    final equipment = equipmentTypes[index];
                    final isSelected =
                        _selectedEquipment == equipment ||
                        (equipment == 'All Equipment' &&
                            _selectedEquipment == null);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getEquipmentIcon(equipment),
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                        ),
                      ),
                      title: Text(
                        equipment,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedEquipment = equipment == 'All Equipment'
                              ? null
                              : equipment;
                        });
                        _filterExercises();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMuscleFilter(BuildContext context) {
    final muscleGroups = _exerciseService.getPrimaryMuscleGroups();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Muscle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: muscleGroups.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = _selectedMuscle == null;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.select_all_rounded,
                            size: 18,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                        ),
                        title: Text(
                          'All Muscles',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedMuscle = null;
                          });
                          _filterExercises();
                        },
                      );
                    }

                    final muscle = muscleGroups[index - 1];
                    final isSelected = _selectedMuscle == muscle;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getMuscleIcon(muscle),
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                        ),
                      ),
                      title: Text(
                        muscle,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedMuscle = muscle;
                        });
                        _filterExercises();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'barbell':
        return Icons.fitness_center;
      case 'dumbbell':
        return Icons.fitness_center;
      case 'machine':
        return Icons.precision_manufacturing;
      case 'cable':
      case 'cable machine':
        return Icons.cable;
      case 'bodyweight':
      case 'none':
        return Icons.accessibility_new;
      case 'kettlebell':
        return Icons.sports_handball;
      case 'plate':
        return Icons.circle_outlined;
      case 'resistance band':
      case 'band':
        return Icons.horizontal_rule;
      case 'suspension':
        return Icons.swap_vert;
      case 'other':
        return Icons.category;
      default:
        return Icons.fitness_center;
    }
  }

  IconData _getMuscleIcon(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
        return Icons.sports_mma;
      case 'back':
      case 'upper back':
      case 'lower back':
      case 'lats':
        return Icons.airline_seat_flat;
      case 'shoulders':
      case 'traps':
        return Icons.accessibility_new;
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return Icons.front_hand;
      case 'abdominals':
      case 'core':
        return Icons.sports_martial_arts;
      case 'quadriceps':
      case 'hamstrings':
      case 'glutes':
      case 'calves':
      case 'abductors':
      case 'adductors':
        return Icons.directions_walk;
      case 'neck':
        return Icons.person;
      case 'cardio':
        return Icons.favorite;
      case 'full body':
        return Icons.accessibility_new;
      default:
        return Icons.circle;
    }
  }
}
class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isActive
          ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1)
          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? colorScheme.primary
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive
                        ? colorScheme.primary
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isActive
                      ? colorScheme.primary
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseListTile extends StatelessWidget {
  final Exercise exercise;
  final bool isDark;
  final VoidCallback onTap;

  const _ExerciseListTile({
    required this.exercise,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muscleColor = AppColors.getMuscleColor(exercise.primaryMuscle);

    return InkWell(
      key: ValueKey(exercise.id),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: exercise.thumbnailUrl != null
                  ? Image.asset(
                      exercise.thumbnailUrl!,
                      key: ValueKey(exercise.thumbnailUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.fitness_center_rounded,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.fitness_center_rounded,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: muscleColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exercise.primaryMuscle,
                          style: TextStyle(
                            color: muscleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.equipment,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String searchQuery;
  final bool isDark;

  const _EmptyView({required this.searchQuery, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 54,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              searchQuery.isEmpty ? 'No exercises found' : 'No results for "$searchQuery"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
