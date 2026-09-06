import 'dart:convert';
import 'package:uuid/uuid.dart';

enum QuestCadence { daily, weekly, boss }

enum QuestMetric {
  setsCompleted,
  workoutsCompleted,
  personalRecords,
  muscleGroupsTrained,
  explorePlans,
  bossClears,
}

class QuestTask {
  final String id;
  final String description;
  final bool isCompleted;

  QuestTask({
    String? id,
    required this.description,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  QuestTask copyWith({
    String? id,
    String? description,
    bool? isCompleted,
  }) {
    return QuestTask(
      id: id ?? this.id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'is_completed': isCompleted,
    };
  }

  factory QuestTask.fromMap(Map<String, dynamic> map) {
    return QuestTask(
      id: map['id'] as String,
      description: map['description'] as String,
      isCompleted: map['is_completed'] as bool? ?? false,
    );
  }
}

class DailyQuest {
  final String id;
  final String label;
  final String title;
  final String description;
  final String type;
  final List<QuestTask> tasks;
  final int rewardXP;
  final bool isElite;
  final bool isRewardClaimed;
  final QuestCadence cadence;
  final QuestMetric metric;
  final int targetCount;
  final int progressCount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isAutoTracked;

  DailyQuest({
    String? id,
    required this.label,
    required this.title,
    required this.description,
    required this.type,
    required this.tasks,
    required this.rewardXP,
    this.isElite = false,
    this.isRewardClaimed = false,
    this.cadence = QuestCadence.daily,
    this.metric = QuestMetric.setsCompleted,
    this.targetCount = 1,
    this.progressCount = 0,
    this.startsAt,
    this.expiresAt,
    this.isAutoTracked = true,
  }) : id = id ?? const Uuid().v4();

  bool get isCompleted {
    if (targetCount > 0) {
      return progressCount >= targetCount;
    }
    return tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
  }

  double get progressPercent {
    if (targetCount <= 0) return isCompleted ? 1 : 0;
    return (progressCount / targetCount).clamp(0.0, 1.0);
  }

  DailyQuest copyWith({
    String? id,
    String? label,
    String? title,
    String? description,
    String? type,
    List<QuestTask>? tasks,
    int? rewardXP,
    bool? isElite,
    bool? isRewardClaimed,
    QuestCadence? cadence,
    QuestMetric? metric,
    int? targetCount,
    int? progressCount,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isAutoTracked,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      label: label ?? this.label,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      tasks: tasks ?? this.tasks,
      rewardXP: rewardXP ?? this.rewardXP,
      isElite: isElite ?? this.isElite,
      isRewardClaimed: isRewardClaimed ?? this.isRewardClaimed,
      cadence: cadence ?? this.cadence,
      metric: metric ?? this.metric,
      targetCount: targetCount ?? this.targetCount,
      progressCount: progressCount ?? this.progressCount,
      startsAt: startsAt ?? this.startsAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isAutoTracked: isAutoTracked ?? this.isAutoTracked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'title': title,
      'description': description,
      'type': type,
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'reward_xp': rewardXP,
      'is_elite': isElite,
      'is_reward_claimed': isRewardClaimed,
      'cadence': cadence.name,
      'metric': metric.name,
      'target_count': targetCount,
      'progress_count': progressCount,
      'starts_at': startsAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_auto_tracked': isAutoTracked,
    };
  }

  factory DailyQuest.fromMap(Map<String, dynamic> map) {
    final cadenceRaw = (map['cadence'] as String?)?.toLowerCase();
    final metricRaw = (map['metric'] as String?)?.toLowerCase();

    return DailyQuest(
      id: map['id'] as String,
      label: map['label'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      tasks: (map['tasks'] as List<dynamic>?)
              ?.map((t) => QuestTask.fromMap(Map<String, dynamic>.from(t as Map)))
              .toList() ??
          [],
      rewardXP: map['reward_xp'] as int,
      isElite: map['is_elite'] as bool? ?? false,
      isRewardClaimed: map['is_reward_claimed'] as bool? ?? false,
      cadence: QuestCadence.values.firstWhere(
        (c) => c.name.toLowerCase() == cadenceRaw,
        orElse: () => QuestCadence.daily,
      ),
      metric: QuestMetric.values.firstWhere(
        (m) => m.name.toLowerCase() == metricRaw,
        orElse: () => QuestMetric.setsCompleted,
      ),
      targetCount: (map['target_count'] as int?) ?? 0,
      progressCount: (map['progress_count'] as int?) ?? 0,
      startsAt: map['starts_at'] != null
          ? DateTime.tryParse(map['starts_at'] as String)
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
      isAutoTracked: map['is_auto_tracked'] as bool? ?? true,
    );
  }

  static List<DailyQuest> decodeList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((entry) => DailyQuest.fromMap(Map<String, dynamic>.from(entry)))
        .toList();
  }

  static String encodeList(List<DailyQuest> quests) {
    return jsonEncode(quests.map((q) => q.toMap()).toList());
  }
}
