enum ReminderState {
  pending('pending'),
  scheduled('scheduled'),
  delivered('delivered'),
  missed('missed'),
  cancelled('cancelled');

  final String value;
  const ReminderState(this.value);

  static ReminderState fromValue(String val) {
    return ReminderState.values.firstWhere(
      (s) => s.value == val,
      orElse: () => ReminderState.pending,
    );
  }
}

class ReminderItem {
  final String id;
  final String ownerType; // 'task', 'event', 'routine'
  final String? ownerId;
  final String title;
  final String? notes;
  final DateTime triggerAt;
  final ReminderState state;
  final int notificationId;
  final DateTime createdAt;

  const ReminderItem({
    required this.id,
    this.ownerType = 'task',
    this.ownerId,
    required this.title,
    this.notes,
    required this.triggerAt,
    this.state = ReminderState.pending,
    required this.notificationId,
    required this.createdAt,
  });

  bool get isUpcoming => triggerAt.isAfter(DateTime.now()) && state != ReminderState.cancelled;
  bool get isDue => triggerAt.isBefore(DateTime.now()) && state == ReminderState.scheduled;

  ReminderItem copyWith({
    String? id,
    String? ownerType,
    String? ownerId,
    String? title,
    String? notes,
    DateTime? triggerAt,
    ReminderState? state,
    int? notificationId,
    DateTime? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      triggerAt: triggerAt ?? this.triggerAt,
      state: state ?? this.state,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_type': ownerType,
      'owner_id': ownerId,
      'title': title,
      'notes': notes,
      'trigger_at_utc': triggerAt.toUtc().toIso8601String(),
      'state': state.value,
      'notification_id': notificationId,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ReminderItem.fromMap(Map<String, dynamic> map) {
    return ReminderItem(
      id: map['id'] as String,
      ownerType: (map['owner_type'] as String?) ?? 'task',
      ownerId: map['owner_id'] as String?,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      triggerAt: DateTime.parse(map['trigger_at_utc'] as String).toLocal(),
      state: ReminderState.fromValue(map['state'] as String? ?? 'pending'),
      notificationId: map['notification_id'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
    );
  }
}
