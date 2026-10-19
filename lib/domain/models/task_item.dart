enum TaskPriority {
  none(0, 'None'),
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'Urgent');

  final int value;
  final String label;
  const TaskPriority(this.value, this.label);

  static TaskPriority fromValue(int val) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == val,
      orElse: () => TaskPriority.none,
    );
  }
}

enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Done'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;
  const TaskStatus(this.value, this.label);

  static TaskStatus fromValue(String val) {
    return TaskStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => TaskStatus.todo,
    );
  }
}

class TaskItem {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;
  final String? timezoneId;
  final String? projectId;
  final String? parentTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.dueAt,
    this.timezoneId,
    this.projectId,
    this.parentTaskId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue =>
      dueAt != null && !isCompleted && dueAt!.isBefore(DateTime.now());

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueAt,
    String? timezoneId,
    String? projectId,
    String? parentTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      timezoneId: timezoneId ?? this.timezoneId,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'due_at_utc': dueAt?.toUtc().toIso8601String(),
      'timezone_id': timezoneId,
      'project_id': projectId,
      'parent_task_id': parentTaskId,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
      'updated_at_utc': updatedAt.toUtc().toIso8601String(),
      'completed_at_utc': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      status: TaskStatus.fromValue(map['status'] as String? ?? 'todo'),
      priority: TaskPriority.fromValue(map['priority'] as int? ?? 2),
      dueAt: map['due_at_utc'] != null
          ? DateTime.parse(map['due_at_utc'] as String).toLocal()
          : null,
      timezoneId: map['timezone_id'] as String?,
      projectId: map['project_id'] as String?,
      parentTaskId: map['parent_task_id'] as String?,
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at_utc'] as String).toLocal(),
      completedAt: map['completed_at_utc'] != null
          ? DateTime.parse(map['completed_at_utc'] as String).toLocal()
          : null,
    );
  }
}
