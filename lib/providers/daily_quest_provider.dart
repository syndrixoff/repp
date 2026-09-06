import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class QuestReward {
  final int xp;
  final String questTitle;
  final String questId;
  final QuestCadence cadence;

  const QuestReward({
    required this.xp,
    required this.questTitle,
    required this.questId,
    required this.cadence,
  });
}

class DailyQuestProvider extends ChangeNotifier {
  static const String _dailyDateKey = 'quests_daily_date';
  static const String _dailyItemsKey = 'quests_daily_items';
  static const String _weeklyDateKey = 'quests_weekly_date';
  static const String _weeklyItemsKey = 'quests_weekly_items';
  static const String _bossItemsKey = 'quests_boss_items';

  final DatabaseService _db = DatabaseService();

  List<DailyQuest> _dailyQuests = [];
  List<DailyQuest> _weeklyQuests = [];
  List<DailyQuest> _bossQuests = [];

  DateTime? _dailyDate;
  DateTime? _weeklyAnchor;
  bool _isLoading = false;

  // Backward-compatible alias used by older widgets.
  List<DailyQuest> get todayQuests => _dailyQuests;
  List<DailyQuest> get dailyQuests => _dailyQuests;
  List<DailyQuest> get weeklyQuests => _weeklyQuests;
  List<DailyQuest> get bossQuests => _bossQuests;

  bool get isLoading => _isLoading;
  int get completedCount =>
      [..._dailyQuests, ..._weeklyQuests, ..._bossQuests]
          .where((q) => q.isCompleted)
          .length;

  Duration get dailyTimeRemaining {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  Duration get weeklyTimeRemaining {
    final now = DateTime.now();
    final daysToNextMonday = (8 - now.weekday) % 7;
    final nextMonday = DateTime(now.year, now.month, now.day + daysToNextMonday);
    final nextReset = DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
    return nextReset.difference(now);
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyDate = DateTime.tryParse(prefs.getString(_dailyDateKey) ?? '');
      _weeklyAnchor = DateTime.tryParse(prefs.getString(_weeklyDateKey) ?? '');

      final dailyString = prefs.getString(_dailyItemsKey);
      final weeklyString = prefs.getString(_weeklyItemsKey);
      final bossString = prefs.getString(_bossItemsKey);

      _dailyQuests =
          (dailyString != null && dailyString.isNotEmpty) ? DailyQuest.decodeList(dailyString) : [];
      _weeklyQuests =
          (weeklyString != null && weeklyString.isNotEmpty) ? DailyQuest.decodeList(weeklyString) : [];
      _bossQuests =
          (bossString != null && bossString.isNotEmpty) ? DailyQuest.decodeList(bossString) : [];

      _cleanupExpiredBossQuests();
    } catch (e) {
      debugPrint('DailyQuestProvider initialize error: $e');
      _dailyQuests = [];
      _weeklyQuests = [];
      _bossQuests = [];
      _dailyDate = null;
      _weeklyAnchor = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> ensureToday({
    required PlayerStats stats,
    required List<Workout> workoutHistory,
  }) async {
    await _ensureQuestWindows(stats);
    await syncProgress(stats: stats, workoutHistory: workoutHistory);
  }

  Future<void> refreshToday({
    required PlayerStats stats,
    required List<Workout> workoutHistory,
  }) async {
    _dailyQuests = _buildDailyQuests(stats: stats);
    _weeklyQuests = _buildWeeklyQuests(stats: stats);
    _dailyDate = DateTime.now();
    _weeklyAnchor = _startOfWeek(DateTime.now());
    await syncProgress(stats: stats, workoutHistory: workoutHistory);
    await _persist();
    notifyListeners();
  }

  Future<void> syncProgress({
    required PlayerStats stats,
    required List<Workout> workoutHistory,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = _startOfWeek(now);

    final allPRs = await _db.getAllPersonalRecords();
    final todaySets = _completedSetsInRange(workoutHistory, todayStart, now);
    final weekSets = _completedSetsInRange(workoutHistory, weekStart, now);
    final weekWorkouts = _completedWorkoutsInRange(workoutHistory, weekStart, now);
    final todayPRs = _personalRecordsInRange(allPRs, todayStart, now);
    final weekPRs = _personalRecordsInRange(allPRs, weekStart, now);

    _dailyQuests = _dailyQuests
        .map((quest) => _updateQuestProgress(
              quest,
              sets: todaySets,
              workouts: 0,
              prs: todayPRs,
              now: now,
              history: workoutHistory,
            ))
        .toList();

    _weeklyQuests = _weeklyQuests
        .map((quest) => _updateQuestProgress(
              quest,
              sets: weekSets,
              workouts: weekWorkouts,
              prs: weekPRs,
              now: now,
              history: workoutHistory,
            ))
        .toList();

    _bossQuests = _bossQuests
        .map((quest) => _updateQuestProgress(
              quest,
              sets: _completedSetsInRange(
                workoutHistory,
                quest.startsAt ?? todayStart,
                quest.expiresAt ?? now,
              ),
              workouts: _completedWorkoutsInRange(
                workoutHistory,
                quest.startsAt ?? todayStart,
                quest.expiresAt ?? now,
              ),
              prs: _personalRecordsInRange(
                allPRs,
                quest.startsAt ?? todayStart,
                quest.expiresAt ?? now,
              ),
              now: now,
              history: workoutHistory,
            ))
        .toList();

    _cleanupExpiredBossQuests();
    await _persist();
    notifyListeners();
  }

  Future<void> registerProgressMilestones({
    required XPAwardResult xpResult,
    required PlayerStats stats,
  }) async {
    final now = DateTime.now();
    final expiry = now.add(const Duration(hours: 48));
    final newBosses = <DailyQuest>[];

    if (xpResult.didLevelUp) {
      final key = 'boss_level_${xpResult.newLevel}';
      if (_bossQuests.every((q) => q.type != key)) {
        final reward = (2000 + stats.level * 20).clamp(2000, 4000);
        newBosses.add(
          DailyQuest(
            id: key,
            label: '[ BOSS QUEST ]',
            title: 'Level ${xpResult.newLevel} Ascension Boss',
            description: 'Complete one full workout before the timer ends.',
            type: key,
            tasks: [QuestTask(description: 'Clear 1 full workout in 48h')],
            rewardXP: reward,
            isElite: true,
            cadence: QuestCadence.boss,
            metric: QuestMetric.workoutsCompleted,
            targetCount: 1,
            progressCount: 0,
            startsAt: now,
            expiresAt: expiry,
          ),
        );
      }
    }

    for (final muscle in xpResult.muscleRankUps) {
      final key =
          'boss_${muscle.toLowerCase()}_${MuscleRankSystem.compactRankLabelFromXP(stats.muscleXP[muscle] ?? 0)}';
      if (_bossQuests.every((q) => q.type != key)) {
        final challenge = _bossChallengeTextForMuscle(muscle: muscle, level: stats.level);
        final reward = (2200 + stats.level * 24).clamp(2000, 4000);
        newBosses.add(
          DailyQuest(
            id: key,
            label: '[ BOSS QUEST ]',
            title: '$muscle Rank-Up Boss',
            description: challenge,
            type: key,
            tasks: [QuestTask(description: challenge)],
            rewardXP: reward,
            isElite: true,
            cadence: QuestCadence.boss,
            metric: QuestMetric.workoutsCompleted,
            targetCount: 1,
            progressCount: 0,
            startsAt: now,
            expiresAt: expiry,
          ),
        );
      }
    }

    if (newBosses.isEmpty) return;

    _bossQuests = [...newBosses, ..._bossQuests];
    await _persist();
    notifyListeners();
  }

  Future<QuestReward?> claimQuestReward(String questId, QuestCadence cadence) async {
    final targetList = _questListForCadence(cadence);
    final index = targetList.indexWhere((q) => q.id == questId);
    if (index == -1) return null;

    final quest = targetList[index];
    if (!quest.isCompleted || quest.isRewardClaimed) return null;

    targetList[index] = quest.copyWith(isRewardClaimed: true);
    await _persist();
    notifyListeners();

    return QuestReward(
      xp: quest.rewardXP,
      questTitle: quest.title,
      questId: quest.id,
      cadence: quest.cadence,
    );
  }

  // Legacy API kept for compatibility with old quest widgets.
  Future<QuestReward?> toggleQuestTask(String questId, String taskId) async {
    return null;
  }

  Future<void> reset() async {
    _dailyQuests = [];
    _weeklyQuests = [];
    _bossQuests = [];
    _dailyDate = null;
    _weeklyAnchor = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyDateKey);
      await prefs.remove(_dailyItemsKey);
      await prefs.remove(_weeklyDateKey);
      await prefs.remove(_weeklyItemsKey);
      await prefs.remove(_bossItemsKey);
    } catch (e) {
      debugPrint('DailyQuestProvider reset error: $e');
    }

    notifyListeners();
  }

  Future<void> _ensureQuestWindows(PlayerStats stats) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = _startOfWeek(now);

    if (!_isSameDay(_dailyDate, today) || _dailyQuests.isEmpty) {
      _dailyQuests = _buildDailyQuests(stats: stats);
      _dailyDate = today;
    }

    if (_weeklyAnchor == null || !_isSameDay(_weeklyAnchor, week) || _weeklyQuests.isEmpty) {
      _weeklyQuests = _buildWeeklyQuests(stats: stats);
      _weeklyAnchor = week;
    }

    _cleanupExpiredBossQuests();
    await _persist();
    notifyListeners();
  }

  List<DailyQuest> _buildDailyQuests({required PlayerStats stats}) {
    return [
      DailyQuest(
        id: 'daily_sets_9',
        label: '[ DAILY QUEST ]',
        title: 'Volume Starter',
        description: 'Complete 9 sets today.',
        type: 'daily_sets_9',
        tasks: [QuestTask(description: 'Complete 9 total sets today')],
        rewardXP: 75,
        cadence: QuestCadence.daily,
        metric: QuestMetric.setsCompleted,
        targetCount: 9,
      ),
      DailyQuest(
        id: 'daily_pr_1',
        label: '[ DAILY QUEST ]',
        title: 'Beat Yesterday',
        description: 'Set at least 1 personal record today.',
        type: 'daily_pr_1',
        tasks: [QuestTask(description: 'Set 1 PR today')],
        rewardXP: 100,
        cadence: QuestCadence.daily,
        metric: QuestMetric.personalRecords,
        targetCount: 1,
      ),
      DailyQuest(
        id: 'daily_sets_15',
        label: '[ DAILY QUEST ]',
        title: 'High Volume Day',
        description: 'Complete 15 sets today.',
        type: 'daily_sets_15',
        tasks: [QuestTask(description: 'Complete 15 total sets today')],
        rewardXP: 100,
        cadence: QuestCadence.daily,
        metric: QuestMetric.setsCompleted,
        targetCount: 15,
      ),
      DailyQuest(
        id: 'daily_adaptive_tip',
        label: '[ DAILY QUEST ]',
        title: 'Adaptive Technique',
        description: stats.level <= 5
            ? 'Use beginner alternatives (wall/knee push-ups, rows, walk intervals).'
            : 'Use strict form and controlled reps for one full session.',
        type: 'daily_adaptive_tip',
        tasks: [
          QuestTask(
            description: stats.level <= 5
                ? 'Beginner mode: keep intensity manageable and finish 9 sets.'
                : 'Maintain strict tempo for at least 9 sets.',
          ),
        ],
        rewardXP: 50,
        cadence: QuestCadence.daily,
        metric: QuestMetric.setsCompleted,
        targetCount: 9,
      ),
    ];
  }

  List<DailyQuest> _buildWeeklyQuests({required PlayerStats stats}) {
    final random = Random(stats.level + DateTime.now().weekday);
    final selectedWeeklyXP = [200, 300, 400, 500]..shuffle(random);

    return [
      DailyQuest(
        id: 'weekly_workouts_4',
        label: '[ WEEKLY QUEST ]',
        title: 'Consistency Block',
        description: 'Complete 4 workouts this week.',
        type: 'weekly_workouts_4',
        tasks: [QuestTask(description: 'Finish 4 workouts this week')],
        rewardXP: selectedWeeklyXP[0],
        cadence: QuestCadence.weekly,
        metric: QuestMetric.workoutsCompleted,
        targetCount: 4,
      ),
      DailyQuest(
        id: 'weekly_sets_60',
        label: '[ WEEKLY QUEST ]',
        title: 'Set Marathon',
        description: 'Complete 60 sets this week.',
        type: 'weekly_sets_60',
        tasks: [QuestTask(description: 'Finish 60 completed sets this week')],
        rewardXP: selectedWeeklyXP[1],
        cadence: QuestCadence.weekly,
        metric: QuestMetric.setsCompleted,
        targetCount: 60,
      ),
      DailyQuest(
        id: 'weekly_prs_3',
        label: '[ WEEKLY QUEST ]',
        title: 'Record Hunter',
        description: 'Hit 3 personal records this week.',
        type: 'weekly_prs_3',
        tasks: [QuestTask(description: 'Set 3 PRs this week')],
        rewardXP: selectedWeeklyXP[2],
        cadence: QuestCadence.weekly,
        metric: QuestMetric.personalRecords,
        targetCount: 3,
      ),
      DailyQuest(
        id: 'weekly_focus_plan',
        label: '[ WEEKLY QUEST ]',
        title: 'Plan Upgrade',
        description: 'Build momentum by completing at least 5 workouts this week.',
        type: 'weekly_focus_plan',
        tasks: [QuestTask(description: 'Complete 5 workouts this week')],
        rewardXP: selectedWeeklyXP[3],
        cadence: QuestCadence.weekly,
        metric: QuestMetric.workoutsCompleted,
        targetCount: 5,
      ),
    ];
  }

  DailyQuest _updateQuestProgress(
    DailyQuest quest, {
    required int sets,
    required int workouts,
    required int prs,
    required DateTime now,
    required List<Workout> history,
  }) {
    if (quest.expiresAt != null && now.isAfter(quest.expiresAt!)) {
      return quest;
    }

    int progress = quest.progressCount;

    switch (quest.metric) {
      case QuestMetric.setsCompleted:
        progress = sets;
        break;
      case QuestMetric.workoutsCompleted:
        progress = workouts;
        break;
      case QuestMetric.personalRecords:
        progress = prs;
        break;
      case QuestMetric.muscleGroupsTrained:
        progress = _trainedMuscleGroupsInRange(
          history,
          quest.startsAt ?? DateTime(now.year, now.month, now.day),
          quest.expiresAt ?? now,
        );
        break;
      case QuestMetric.explorePlans:
      case QuestMetric.bossClears:
        break;
    }

    return quest.copyWith(progressCount: progress);
  }

  int _trainedMuscleGroupsInRange(List<Workout> history, DateTime start, DateTime end) {
    final muscles = <String>{};
    for (final workout in history) {
      if (workout.endTime == null || workout.startTime.isBefore(start) || workout.startTime.isAfter(end)) {
        continue;
      }
      for (final exercise in workout.exercises) {
        final normalized = MuscleRankSystem.normalizeMuscleGroup(exercise.exerciseName);
        if (normalized != 'Other') {
          muscles.add(normalized);
        }
      }
    }
    return muscles.length;
  }

  List<DailyQuest> _questListForCadence(QuestCadence cadence) {
    switch (cadence) {
      case QuestCadence.daily:
        return _dailyQuests;
      case QuestCadence.weekly:
        return _weeklyQuests;
      case QuestCadence.boss:
        return _bossQuests;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_dailyDate != null) {
      await prefs.setString(_dailyDateKey, _dailyDate!.toIso8601String());
    }
    if (_weeklyAnchor != null) {
      await prefs.setString(_weeklyDateKey, _weeklyAnchor!.toIso8601String());
    }
    await prefs.setString(_dailyItemsKey, DailyQuest.encodeList(_dailyQuests));
    await prefs.setString(_weeklyItemsKey, DailyQuest.encodeList(_weeklyQuests));
    await prefs.setString(_bossItemsKey, DailyQuest.encodeList(_bossQuests));
  }

  int _completedSetsInRange(List<Workout> history, DateTime start, DateTime end) {
    return history
        .where((w) => w.endTime != null && !w.startTime.isBefore(start) && !w.startTime.isAfter(end))
        .fold<int>(0, (sum, workout) => sum + workout.completedSets);
  }

  int _completedWorkoutsInRange(List<Workout> history, DateTime start, DateTime end) {
    return history
        .where((w) => w.endTime != null && !w.startTime.isBefore(start) && !w.startTime.isAfter(end))
        .length;
  }

  int _personalRecordsInRange(List<PersonalRecord> records, DateTime start, DateTime end) {
    return records
        .where((pr) => !pr.achievedAt.isBefore(start) && !pr.achievedAt.isAfter(end))
        .length;
  }

  DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(start.year, start.month, start.day);
  }

  void _cleanupExpiredBossQuests() {
    final now = DateTime.now();
    _bossQuests = _bossQuests.where((q) {
      if (q.expiresAt == null) return true;
      return now.isBefore(q.expiresAt!) || (q.isCompleted && q.isRewardClaimed);
    }).toList();
  }

  String _bossChallengeTextForMuscle({required String muscle, required int level}) {
    final isBeginner = level <= 5;
    switch (muscle) {
      case 'Chest':
        return isBeginner
            ? 'Chest boss: 20 wall push-ups + 10 knee push-ups.'
            : 'Chest boss: 20 push-ups + 10 incline push-ups.';
      case 'Back':
        return isBeginner
            ? 'Back boss: 25 resistance-band rows.'
            : 'Back boss: 15 pull-ups or 25 rows.';
      case 'Legs':
        return isBeginner
            ? 'Leg boss: 20 bodyweight squats + 20 walking lunges.'
            : 'Leg boss: 25 squats + 20 lunges.';
      case 'Shoulders':
        return isBeginner
            ? 'Shoulder boss: 20 pike holds + 15 raises.'
            : 'Shoulder boss: 20 pike push-ups + 20 raises.';
      case 'Arms':
        return isBeginner
            ? 'Arms boss: 30 controlled curls + 30 band extensions.'
            : 'Arms boss: 40 curls + 40 triceps reps.';
      default:
        return isBeginner
            ? 'Boss trial: complete one full beginner-friendly workout.'
            : 'Boss trial: complete one high-intensity full workout.';
    }
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
