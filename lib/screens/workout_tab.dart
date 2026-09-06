import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'exercises_tab.dart';
import '../providers/history_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import 'active_workout_screen.dart';
import 'create_routine_screen.dart';
import 'guided_workout_screen.dart';
import 'view_routine_screen.dart';
import 'player_profile_screen.dart';

class WorkoutTab extends StatelessWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final routineProvider = context.watch<RoutineProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final historyProvider = context.watch<HistoryProvider>();
    final dailyQuestProvider = context.read<DailyQuestProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final todaysRoutineCount = routineProvider.routines
        .where((routine) => routine.isPlannedForDate(today))
        .length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<DailyQuestProvider>().ensureToday(
        stats: playerProvider.stats,
        workoutHistory: historyProvider.workoutHistory,
      );
    });

    // If there's an active free-form workout (not from a routine), show the active workout screen
    if (workoutProvider.hasActiveWorkout &&
        workoutProvider.activeWorkout?.routineId == null) {
      return const ActiveWorkoutScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.14 : 0.1,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(
                    alpha: isDark ? 0.12 : 0.08,
                  ),
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async {
              await routineProvider.loadRoutines();
              await playerProvider.refresh();
              await historyProvider.refresh();
              await dailyQuestProvider.ensureToday(
                stats: playerProvider.stats,
                workoutHistory: historyProvider.workoutHistory,
              );
            },
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Player Dashboard Header
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _PlayerDashboard(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _WelcomeOverviewCard(
                      routineCount: todaysRoutineCount,
                      hasActiveWorkout: workoutProvider.hasActiveWorkout,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // Quick Start Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Start',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _QuickStartButton(
                          onTap: () async {
                            await workoutProvider.startEmptyWorkout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // Routines Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Routines',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                        ),
                        _AddRoutineButton(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateRoutineScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Routine Action Buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RoutineActionButton(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'New Routine',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateRoutineScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoutineActionButton(
                            icon: Icons.explore_outlined,
                            label: 'Explore',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ExercisesTab(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Routines List
                if (routineProvider.isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                else if (routineProvider.routines.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyRoutinesCard(isDark: isDark),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final routine = routineProvider.routines[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _RoutineCard(
                          routine: routine,
                          onStart: () async {
                            await workoutProvider.startFromRoutine(routine);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const GuidedWorkoutScreen(),
                                ),
                              );
                            }
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ViewRoutineScreen(routineId: routine.id),
                              ),
                            );
                          },
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateRoutineScreen(routine: routine),
                              ),
                            );
                          },
                          onDelete: () async {
                            final confirm = await _showDeleteDialog(
                              context,
                              routine,
                            );
                            if (confirm == true) {
                              await routineProvider.deleteRoutine(routine.id);
                            }
                          },
                        ),
                      );
                    }, childCount: routineProvider.routines.length),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 150)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, Routine routine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
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
                  'Delete Routine?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${routine.name}" will be permanently deleted.',
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
  }
}

// ============================================================
// Player Dashboard — Solo Leveling styled
// ============================================================

class _PlayerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.systemPanelGradient
              : const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.systemBlue.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.systemBlue.withValues(alpha: 0.1),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: rank badge + name + streak
            Row(
              children: [
                // Rank badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.systemBlue.withValues(alpha: 0.3),
                        AppColors.systemPurple.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.systemBlue.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      player.rankLetter,
                      style: TextStyle(
                        color: AppColors.systemBlue,
                        fontSize: player.rankLetter.length > 1 ? 16 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Level ${player.level} • ${player.title}',
                        style: TextStyle(
                          color: AppColors.systemPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak
                if (player.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${player.currentStreak}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // XP progress bar
            Row(
              children: [
                Text(
                  'XP',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: player.progressPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.xpBarGradient,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.systemBlue.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${player.xpInCurrentLevel}/${player.xpToNextLevel}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Daily Quest Panel
// ============================================================

class _DailyQuestPanel extends StatefulWidget {
  final DailyQuestProvider questProvider;

  const _DailyQuestPanel({required this.questProvider});

  @override
  State<_DailyQuestPanel> createState() => _DailyQuestPanelState();
}

class _DailyQuestPanelState extends State<_DailyQuestPanel> {
  Timer? _timer;
  late String _timeRemaining;

  @override
  void initState() {
    super.initState();
    _timeRemaining = _timeUntilReset();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeRemaining = _timeUntilReset());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = widget.questProvider.todayQuests;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (quests.isEmpty) {
      return _GlassPanel(
        borderRadius: 16,
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.systemBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Generating adaptive daily quests...',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quests',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'TIME REMAINING: $_timeRemaining',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quests.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final quest = quests[index];
              return _buildQuestCard(context, quest, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard(BuildContext context, DailyQuest quest, bool isDark) {
    final completedTasks = quest.tasks.where((t) => t.isCompleted).length;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showQuestDetailsSheet(context, quest, isDark),
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2740) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: quest.isCompleted
                ? AppColors.success.withValues(alpha: 0.7)
                : AppColors.systemBlue.withValues(alpha: 0.45),
            width: quest.isCompleted ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quest.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: quest.isElite
                          ? Colors.redAccent
                          : AppColors.systemBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Icon(
              quest.isCompleted ? Icons.check_circle : Icons.shield_outlined,
              color: quest.isCompleted
                  ? AppColors.success
                  : AppColors.systemBlue,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              quest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            const Spacer(),
            Text(
              '$completedTasks/${quest.tasks.length} tasks complete',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+${quest.rewardXP} XP',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuestDetailsSheet(
    BuildContext context,
    DailyQuest quest,
    bool isDark,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final currentQuest = widget.questProvider.todayQuests.firstWhere(
              (q) => q.id == quest.id,
              orElse: () => quest,
            );

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentQuest.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentQuest.description,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...currentQuest.tasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: InkWell(
                          onTap: () async {
                            final playerProvider = context
                                .read<PlayerProvider>();
                            final messenger = ScaffoldMessenger.of(context);
                            final reward = await widget.questProvider
                                .toggleQuestTask(currentQuest.id, task.id);
                            if (!mounted) return;

                            if (reward != null) {
                              await playerProvider.addQuestXP(
                                reward.xp,
                                reward.questTitle,
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Quest completed: +${reward.xp} XP',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }

                            setSheetState(() {});
                          },
                          child: Row(
                            children: [
                              Icon(
                                task.isCompleted
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: task.isCompleted
                                    ? AppColors.success
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black45),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  task.description,
                                  style: TextStyle(
                                    color: task.isCompleted
                                        ? (isDark
                                              ? Colors.white38
                                              : Colors.black38)
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _timeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _WelcomeOverviewCard extends StatelessWidget {
  final int routineCount;
  final bool hasActiveWorkout;

  const _WelcomeOverviewCard({
    required this.routineCount,
    required this.hasActiveWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return _GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActiveWorkout ? 'Workout in progress' : 'Ready for today?',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasActiveWorkout
                      ? 'Pick up where you left off and keep momentum.'
                      : 'You have $routineCount routine${routineCount == 1 ? '' : 's'} lined up.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
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

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: isDark
              ? AppColors.glassGradientDark
              : AppColors.glassGradientLight,
          border: Border.all(
            color: isDark
                ? AppColors.darkGlassBorder
                : AppColors.lightGlassBorder,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ============================================================
// Existing widgets preserved below (Quick Start, Routine cards, etc.)
// ============================================================

/// Gradient Quick Start button
class _QuickStartButton extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickStartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return _GlassPanel(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [AppColors.primary, Color(0xFF1E293B)]
                    : const [AppColors.primary, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryTextColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: primaryTextColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Empty Workout',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track exercises as you go',
                          style: TextStyle(
                            color: primaryTextColor.withValues(alpha: 0.74),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: primaryTextColor.withValues(alpha: 0.72),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRoutineButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddRoutineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 20,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _RoutineActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoutineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_RoutineActionButton> createState() => _RoutineActionButtonState();
}

class _RoutineActionButtonState extends State<_RoutineActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _isPressed ? 0.97 : 1,
        child: Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
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

class _EmptyRoutinesCard extends StatelessWidget {
  final bool isDark;

  const _EmptyRoutinesCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      borderRadius: 16,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 36,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Routines Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a routine to quickly start\nyour workouts with predefined exercises.',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final VoidCallback onStart;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.onStart,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final subtleFillColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : AppColors.lightSurfaceVariant;

    return _GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (routine.exercises.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${routine.exercises.length} exercise${routine.exercises.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _RoutineMenuButton(
                      onEdit: onEdit,
                      onDelete: onDelete,
                      isDark: isDark,
                    ),
                  ],
                ),
                if (routine.exerciseSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: subtleFillColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: routine.exercises.map((exercise) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '- ${exercise.exerciseName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.4,
                            ),
                            softWrap: true,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Start Routine',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: AppColors.lightTextPrimary,
                      elevation: 0,
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
      ),
    );
  }
}

class _RoutineMenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;

  const _RoutineMenuButton({
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 10),
              const Text('Edit'),
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
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
