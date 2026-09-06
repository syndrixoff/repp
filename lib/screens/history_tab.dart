import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Calendar view coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => historyProvider.refresh(),
        child:
            historyProvider.isLoading && historyProvider.workoutHistory.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : historyProvider.workoutHistory.isEmpty
            ? _EmptyHistoryView(isDark: isDark)
            : CustomScrollView(
                slivers: [
                  // Stats summary
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ENERGY CHAMBER',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.systemBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '[ SYSTEM ACTIVE ]',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.systemBlue,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatsSummaryCard(
                          totalWorkouts: historyProvider.totalWorkouts,
                          thisWeekWorkouts: historyProvider.thisWeekWorkouts,
                          avgDuration: historyProvider.avgDurationMinutes,
                          totalVolume: historyProvider.totalVolume,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // Recent PRs
                  if (historyProvider.recentPRs.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                        child: Text(
                          'ASCENSION RECORDS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: historyProvider.recentPRs.length,
                          itemBuilder: (context, index) {
                            final pr = historyProvider.recentPRs[index];
                            return _PRCard(pr: pr, isDark: isDark);
                          },
                        ),
                      ),
                    ),
                  ],

                  // Workout history header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                      child: Text(
                        'TACTICAL LOGS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // Workout list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= historyProvider.workoutHistory.length) {
                          if (historyProvider.hasMore) {
                            historyProvider.loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return null;
                        }

                        final workout = historyProvider.workoutHistory[index];
                        return _WorkoutHistoryCard(
                          workout: workout,
                          isDark: isDark,
                          onTap: () => _showWorkoutDetails(context, workout.id),
                          onDelete: () =>
                              _deleteWorkout(context, historyProvider, workout),
                        );
                      },
                      childCount:
                          historyProvider.workoutHistory.length +
                          (historyProvider.hasMore ? 1 : 0),
                    ),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  void _showWorkoutDetails(BuildContext context, String workoutId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _WorkoutDetailsSheet(
          workoutId: workoutId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _deleteWorkout(
    BuildContext context,
    HistoryProvider historyProvider,
    Workout workout,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
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
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Delete Workout?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${workout.name}" will be permanently deleted.',
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
                    onPressed: () => Navigator.pop(context, true),
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
                      'Delete',
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
                    onPressed: () => Navigator.pop(context, false),
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
                      'Cancel',
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

    if (confirm == true) {
      await historyProvider.deleteWorkout(workout.id);
    }
  }
}

class _StatsSummaryCard extends StatelessWidget {
  final int totalWorkouts;
  final int thisWeekWorkouts;
  final double avgDuration;
  final double totalVolume;
  final bool isDark;

  const _StatsSummaryCard({
    required this.totalWorkouts,
    required this.thisWeekWorkouts,
    required this.avgDuration,
    required this.totalVolume,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'TOTAL WORKOUTS',
                  value: totalWorkouts.toString(),
                  icon: Icons.bolt,
                  color: AppColors.systemBlue,
                  progressVal: 0.6,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'THIS WEEK',
                  value: thisWeekWorkouts.toString(),
                  icon: Icons.calendar_today,
                  color: AppColors.systemPurple,
                  progressVal: thisWeekWorkouts / 7.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'AVG DURATION',
                  value: '${avgDuration.toStringAsFixed(0)}m',
                  icon: Icons.timer_outlined,
                  color: AppColors.systemBlue,
                  progressVal: 0.4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'TOTAL VOLUME',
                  value: _formatVolume(totalVolume),
                  icon: Icons.fitness_center,
                  color: AppColors.systemPurple,
                  progressVal: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}t';
    }
    return '${volume.toStringAsFixed(0)}kg';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double progressVal;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.progressVal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, size: 20, color: isDark ? Colors.white24 : Colors.black26),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressVal.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PRCard extends StatelessWidget {
  final PersonalRecord pr;
  final bool isDark;

  const _PRCard({required this.pr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.military_tech,
                color: AppColors.systemBlue,
                size: 24,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.systemBlue.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.systemBlue.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEW RECORD',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.systemBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            pr.exerciseName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                pr.formattedValue.replaceAll(RegExp(r'[^0-9.]'), ''),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                pr.formattedValue.replaceAll(RegExp(r'[0-9.\s]'), '').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.systemBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'HASH_RECO_${pr.achievedAt.millisecondsSinceEpoch.toString().substring(0, 5)}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  final Workout workout;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkoutHistoryCard({
    required this.workout,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final endTimeFormat = DateFormat('HH:mm');

    final duration = workout.duration ?? const Duration();
    final endTime = workout.startTime.add(duration);
    final durationString = '${timeFormat.format(workout.startTime)} - ${endTimeFormat.format(endTime)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
        border: Border(
          left: BorderSide(
            color: AppColors.systemBlue,
            width: 4,
          ),
          top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
          right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
          bottom: BorderSide(
            color: AppColors.systemBlue.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OPERATION: STRENGTH ALPHA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.systemBlue,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    dateFormat.format(workout.startTime).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      workout.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Text(
                    durationString,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.systemBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TacticalStat(
                      label: 'EXERCISES',
                      value: workout.exercises.length.toString(),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TacticalStat(
                      label: 'VOLUME',
                      value: '${(workout.totalVolume / 1000).toStringAsFixed(1)}t',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'XP GAIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white54 : Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${workout.totalVolume > 0 ? (workout.totalVolume / 100).ceil() + 50 : 50}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.systemBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _TacticalStat({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutDetailsSheet extends StatelessWidget {
  final String workoutId;
  final ScrollController scrollController;

  const _WorkoutDetailsSheet({
    required this.workoutId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workout = context.watch<HistoryProvider>().getCachedWorkoutById(
      workoutId,
    );

    if (workout == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('This workout is no longer available.'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Header
                Text(
                  workout.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${dateFormat.format(workout.startTime)} at ${timeFormat.format(workout.startTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DetailStatItem(
                        label: 'Duration',
                        value: workout.durationString,
                        icon: Icons.timer_rounded,
                        color: AppColors.accentOrange,
                        isDark: isDark,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200,
                      ),
                      _DetailStatItem(
                        label: 'Volume',
                        value: '${workout.totalVolume.toStringAsFixed(0)}kg',
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200,
                      ),
                      _DetailStatItem(
                        label: 'Sets',
                        value: workout.completedSets.toString(),
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Exercises header
                Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),

                // Exercises
                ...workout.exercises.map(
                  (exercise) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.exerciseName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...exercise.sets.map(
                          (set) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: set.isCompleted
                                        ? AppColors.success.withValues(alpha: 0.12)
                                        : (isDark
                                              ? Colors.white.withValues(alpha: 0.05)
                                              : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    set.isWarmup
                                        ? 'W'
                                        : set.isDropSet
                                        ? 'D'
                                        : set.isFailure
                                        ? 'F'
                                        : '${set.setNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: set.isWarmup
                                          ? Colors.orange
                                          : set.isDropSet
                                          ? Colors.blue
                                          : set.isFailure
                                          ? AppColors.error
                                          : (set.isCompleted
                                                ? AppColors.success
                                                : (isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    set.displayString,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (set.isCompleted)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _DetailStatItem({
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
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
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

class _EmptyHistoryView extends StatelessWidget {
  final bool isDark;

  const _EmptyHistoryView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 52,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Workout History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Complete your first workout to start\ntracking your progress over time.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

