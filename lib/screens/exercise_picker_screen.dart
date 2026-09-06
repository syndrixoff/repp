import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/exercise_service.dart';
import 'exercise_detail_screen.dart';

class ExercisePickerScreen extends StatefulWidget {
  final bool multiSelect;

  const ExercisePickerScreen({super.key, this.multiSelect = false});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final ExerciseService _exerciseService = ExerciseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedEquipment;
  String? _selectedMuscle;
  List<Exercise> _filteredExercises = [];
  final Set<Exercise> _selectedExercises = {};
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
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        leadingWidth: 80,
        title: const Text('Add Exercise'),
        actions: [
          if (widget.multiSelect)
            TextButton(
              onPressed: _selectedExercises.isNotEmpty
                  ? () => Navigator.pop(context, _selectedExercises.toList())
                  : null,
              child: Text('Add (${_selectedExercises.length})'),
            )
          else
            TextButton(
              onPressed: () => _showCreateExerciseDialog(context),
              child: const Text('Create'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Exercise',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _filterExercises();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterExercises();
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: _selectedEquipment ?? 'All Equipment',
                  isSelected: _selectedEquipment != null,
                  onTap: () => _showEquipmentPicker(context),
                  onClear: _selectedEquipment != null
                      ? () {
                          setState(() {
                            _selectedEquipment = null;
                          });
                          _filterExercises();
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _selectedMuscle ?? 'All Muscles',
                  isSelected: _selectedMuscle != null,
                  onTap: () => _showMusclePicker(context),
                  onClear: _selectedMuscle != null
                      ? () {
                          setState(() {
                            _selectedMuscle = null;
                          });
                          _filterExercises();
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isLoading
                    ? 'Loading exercises...'
                    : '${_filteredExercises.length} exercises',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),

          // Exercise list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExercises.isEmpty
                ? _EmptyResultsView(
                    searchQuery: _searchQuery,
                    onCreateExercise: () => _showCreateExerciseDialog(context),
                  )
                : ListView.builder(
                    itemCount: _filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      final isSelected = _selectedExercises.contains(exercise);

                      return _ExerciseListTile(
                        exercise: exercise,
                        isSelected: isSelected,
                        multiSelect: widget.multiSelect,
                        onTap: () {
                          if (widget.multiSelect) {
                            setState(() {
                              if (isSelected) {
                                _selectedExercises.remove(exercise);
                              } else {
                                _selectedExercises.add(exercise);
                              }
                            });
                          } else {
                            Navigator.pop(context, exercise);
                          }
                        },
                        onLongPress: widget.multiSelect
                            ? () => _openExerciseDetails(exercise)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEquipmentPicker(BuildContext context) {
    final equipmentTypes = _exerciseService.getEquipmentTypes();

    showModalBottomSheet(
      context: context,
      builder: (context) => _PickerBottomSheet(
        title: 'Select Equipment',
        items: equipmentTypes,
        selectedItem: _selectedEquipment,
        onSelect: (item) {
          Navigator.pop(context);
          setState(() {
            _selectedEquipment = item == 'All Equipment' ? null : item;
          });
          _filterExercises();
        },
      ),
    );
  }

  void _showMusclePicker(BuildContext context) {
    final muscleGroups = _exerciseService.getPrimaryMuscleGroups();

    showModalBottomSheet(
      context: context,
      builder: (context) => _PickerBottomSheet(
        title: 'Select Muscle Group',
        items: ['All Muscles', ...muscleGroups],
        selectedItem: _selectedMuscle,
        onSelect: (item) {
          Navigator.pop(context);
          setState(() {
            _selectedMuscle = item == 'All Muscles' ? null : item;
          });
          _filterExercises();
        },
      ),
    );
  }

  void _showCreateExerciseDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedEquipment = 'None';
    String selectedMuscle = 'Other';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                    hintText: 'e.g., Barbell Curl',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedEquipment,
                  decoration: const InputDecoration(labelText: 'Equipment'),
                  items: EquipmentType.all
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedEquipment = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMuscle,
                  decoration: const InputDecoration(
                    labelText: 'Primary Muscle',
                  ),
                  items: MuscleGroup.all
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedMuscle = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an exercise name'),
                    ),
                  );
                  return;
                }

                final newExercise = await _exerciseService.addCustomExercise(
                  name: nameController.text.trim(),
                  equipment: selectedEquipment,
                  primaryMuscle: selectedMuscle,
                );

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, newExercise); // Return exercise
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _openExerciseDetails(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailScreen(exerciseId: exercise.id),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: onClear != null ? 8 : 16,
            top: 10,
            bottom: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
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
  final bool isSelected;
  final bool multiSelect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ExerciseListTile({
    required this.exercise,
    required this.isSelected,
    required this.multiSelect,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(exercise.id),
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: exercise.thumbnailUrl != null
            ? Image.asset(
                exercise.thumbnailUrl!,
                key: ValueKey(exercise.thumbnailUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.fitness_center, color: Colors.grey.shade400),
              )
            : Icon(Icons.fitness_center, color: Colors.grey.shade400),
      ),
      title: Text(
        exercise.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        exercise.primaryMuscle,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : Icon(
              multiSelect ? Icons.radio_button_unchecked : Icons.chevron_right,
            ),
      selected: isSelected,
    );
  }
}

class _PickerBottomSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final Function(String) onSelect;

  const _PickerBottomSheet({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected =
                    item == selectedItem ||
                    (selectedItem == null && index == 0);

                return ListTile(
                  title: Text(item),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => onSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResultsView extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onCreateExercise;

  const _EmptyResultsView({
    required this.searchQuery,
    required this.onCreateExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty
                  ? 'No exercises found'
                  : 'No exercises found for "$searchQuery"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters, or create a custom exercise',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onCreateExercise,
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}
