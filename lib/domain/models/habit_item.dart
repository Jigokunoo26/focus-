class HabitItem {
  final String id;
  final String name;
  final String scheduleRule; // 'daily', 'weekdays'
  final int targetPerPeriod;
  final int currentStreak;
  final int bestStreak;
  final bool isCompletedToday;
  final DateTime createdAt;

  const HabitItem({
    required this.id,
    required this.name,
    this.scheduleRule = 'daily',
    this.targetPerPeriod = 1,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.isCompletedToday = false,
    required this.createdAt,
  });

  HabitItem copyWith({
    String? id,
    String? name,
    String? scheduleRule,
    int? targetPerPeriod,
    int? currentStreak,
    int? bestStreak,
    bool? isCompletedToday,
    DateTime? createdAt,
  }) {
    return HabitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduleRule: scheduleRule ?? this.scheduleRule,
      targetPerPeriod: targetPerPeriod ?? this.targetPerPeriod,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'schedule_rule': scheduleRule,
      'target_per_period': targetPerPeriod,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'is_completed_today': isCompletedToday ? 1 : 0,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
    };
  }

  factory HabitItem.fromMap(Map<String, dynamic> map) {
    return HabitItem(
      id: map['id'] as String,
      name: map['name'] as String,
      scheduleRule: (map['schedule_rule'] as String?) ?? 'daily',
      targetPerPeriod: map['target_per_period'] as int? ?? 1,
      currentStreak: map['current_streak'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      isCompletedToday: (map['is_completed_today'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
    );
  }
}
