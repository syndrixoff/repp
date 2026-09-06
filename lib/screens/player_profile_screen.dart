import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/history_provider.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

/// Standalone player profile screen — navigable from dashboard
class PlayerProfileScreen extends StatelessWidget {
  const PlayerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final history = context.watch<HistoryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hunter Profile',
          style: TextStyle(
            color: AppColors.systemBlue,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Level & Rank card
          _RankCard(player: player),
          const SizedBox(height: 20),

          // XP Progress
          _XPProgressSection(player: player),
          const SizedBox(height: 20),

          // Stats
          _StatsSection(
            totalWorkouts: history.totalWorkouts,
            totalVolume: history.totalVolume,
            totalSets: history.totalSets,
            currentStreak: player.currentStreak,
            longestStreak: player.longestStreak,
          ),
          const SizedBox(height: 20),

          // Muscle XP Breakdown
          if (player.muscleXP.isNotEmpty)
            _MuscleBreakdown(muscleXP: player.muscleXP),

          if (player.muscleXP.isNotEmpty)
            const SizedBox(height: 20),

          // Recent XP Log
          if (player.recentLogs.isNotEmpty)
            _RecentXPLog(logs: player.recentLogs),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final PlayerProvider player;

  const _RankCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppColors.systemPanelGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.systemBlue.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.systemBlue.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Rank badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.systemBlue.withValues(alpha: 0.3),
                  AppColors.systemPurple.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: AppColors.systemBlue.withValues(alpha: 0.6),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.systemBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                player.rankLetter,
                style: TextStyle(
                  color: AppColors.systemBlue,
                  fontSize: player.rankLetter.length > 1 ? 24 : 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Level ${player.level}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            player.title,
            style: TextStyle(
              color: AppColors.systemPurple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total XP: ${_formatNumber(player.totalXP)}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _XPProgressSection extends StatelessWidget {
  final PlayerProvider player;

  const _XPProgressSection({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${player.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Level ${player.level + 1}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: player.progressPercent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.xpBarGradient,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.systemBlue.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${player.xpInCurrentLevel} / ${player.xpToNextLevel} XP',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final int totalWorkouts;
  final double totalVolume;
  final int totalSets;
  final int currentStreak;
  final int longestStreak;

  const _StatsSection({
    required this.totalWorkouts,
    required this.totalVolume,
    required this.totalSets,
    required this.currentStreak,
    required this.longestStreak,
  });

  String _formatVolume(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HUNTER STATS',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(icon: Icons.fitness_center, value: '$totalWorkouts', label: 'Workouts'),
              _StatTile(icon: Icons.trending_up, value: '${_formatVolume(totalVolume)} kg', label: 'Volume'),
              _StatTile(icon: Icons.check_circle_outline, value: '$totalSets', label: 'Sets'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                icon: Icons.local_fire_department,
                value: '$currentStreak',
                label: 'Streak',
                iconColor: Colors.orange,
              ),
              _StatTile(
                icon: Icons.emoji_events,
                value: '$longestStreak',
                label: 'Best Streak',
                iconColor: Colors.amber,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor ?? AppColors.systemBlue, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleBreakdown extends StatelessWidget {
  final Map<String, int> muscleXP;

  const _MuscleBreakdown({required this.muscleXP});

  @override
  Widget build(BuildContext context) {
    final sorted = muscleXP.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxXP = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MUSCLE MASTERY',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final progress = entry.value / maxXP;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.getMuscleColor(entry.key),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${entry.value} XP',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.xpGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

class _RecentXPLog extends StatelessWidget {
  final List<XPLog> logs;

  const _RecentXPLog({required this.logs});

  IconData _iconForSource(String source) {
    switch (source) {
      case 'set_complete':
        return Icons.check_circle_outline;
      case 'reps_bonus':
        return Icons.repeat_rounded;
      case 'weight_bonus':
        return Icons.fitness_center_rounded;
      case 'workout_complete':
        return Icons.emoji_events_outlined;
      case 'streak_bonus':
        return Icons.local_fire_department;
      case 'pr_bonus':
        return Icons.star_rounded;
      default:
        return Icons.bolt;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XP LOG',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...logs.take(10).map((log) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  _iconForSource(log.source),
                  color: AppColors.systemBlue,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.details ?? log.source,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '+${log.amount}',
                  style: TextStyle(
                    color: AppColors.xpGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeAgo(log.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
