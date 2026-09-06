import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/history_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';

class QuestsTab extends StatefulWidget {
  const QuestsTab({super.key});

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      final history = context.read<HistoryProvider>();
      final quests = context.read<DailyQuestProvider>();
      await quests.ensureToday(stats: player.stats, workoutHistory: history.workoutHistory);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<DailyQuestProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Boss'),
            ],
          ),
        ),
        body: Column(
          children: [
            _QuestTimers(
              dailyRemaining: questProvider.dailyTimeRemaining,
              weeklyRemaining: questProvider.weeklyTimeRemaining,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _QuestList(quests: questProvider.dailyQuests),
                  _QuestList(quests: questProvider.weeklyQuests),
                  _QuestList(quests: questProvider.bossQuests),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestTimers extends StatelessWidget {
  final Duration dailyRemaining;
  final Duration weeklyRemaining;

  const _QuestTimers({required this.dailyRemaining, required this.weeklyRemaining});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _TimerCard(
              title: 'Daily Reset',
              value: _formatDuration(dailyRemaining),
              icon: Icons.today_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TimerCard(
              title: 'Weekly Reset',
              value: _formatDuration(weeklyRemaining),
              icon: Icons.date_range_rounded,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final total = value.isNegative ? Duration.zero : value;
    final d = total.inDays;
    final h = (total.inHours % 24).toString().padLeft(2, '0');
    final m = (total.inMinutes % 60).toString().padLeft(2, '0');
    final s = (total.inSeconds % 60).toString().padLeft(2, '0');
    if (d > 0) return '${d}d $h:$m:$s';
    return '$h:$m:$s';
  }
}

class _TimerCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TimerCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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

class _QuestList extends StatelessWidget {
  final List<DailyQuest> quests;

  const _QuestList({required this.quests});

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return const Center(child: Text('No quests available right now.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) => _QuestCard(quest: quests[index]),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: quests.length,
    );
  }
}

class _QuestCard extends StatelessWidget {
  final DailyQuest quest;

  const _QuestCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canClaim = quest.isCompleted && !quest.isRewardClaimed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canClaim
              ? AppColors.primary.withValues(alpha: 0.8)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            quest.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            quest.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: quest.progressPercent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${quest.progressCount}/${quest.targetCount}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                '+${quest.rewardXP} XP',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canClaim
                  ? () async {
                      try {
                        final questProvider = context.read<DailyQuestProvider>();
                        final playerProvider = context.read<PlayerProvider>();
                        final historyProvider = context.read<HistoryProvider>();

                        debugPrint('[QuestsTab] Claiming reward for quest: ${quest.id}');
                        final reward = await questProvider.claimQuestReward(
                          quest.id,
                          quest.cadence,
                        );
                        
                        if (reward == null) {
                          debugPrint('[QuestsTab] ERROR: Quest reward is null - quest may already be claimed or not completed');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not claim reward - quest may already be claimed')),
                          );
                          return;
                        }
                        
                        if (!context.mounted) return;

                        debugPrint('[QuestsTab] Adding XP: ${reward.xp} XP for "${reward.questTitle}"');
                        await playerProvider.addQuestXP(reward.xp, reward.questTitle);
                        
                        debugPrint('[QuestsTab] Ensuring today quests are updated');
                        await questProvider.ensureToday(
                          stats: playerProvider.stats,
                          workoutHistory: historyProvider.workoutHistory,
                        );

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Quest reward claimed: +${reward.xp} XP')),
                        );
                      } catch (e) {
                        debugPrint('[QuestsTab] ERROR claiming quest reward: $e');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error claiming reward: $e')),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                foregroundColor: AppColors.lightTextPrimary,
                backgroundColor: canClaim
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
              ),
              child: Text(
                quest.isRewardClaimed
                    ? 'Claimed'
                    : (quest.isCompleted ? 'Claim Reward' : 'In Progress'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

