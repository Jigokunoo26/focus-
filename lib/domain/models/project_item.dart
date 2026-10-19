class ProjectItem {
  final String id;
  final String name;
  final String description;
  final String status;
  final String colorHex;
  final String iconName;
  final DateTime? deadline;
  final DateTime createdAt;

  const ProjectItem({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'active',
    this.colorHex = '#FFFFFF',
    this.iconName = 'folder',
    this.deadline,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'color_hex': colorHex,
      'icon_name': iconName,
      'deadline_utc': deadline?.toUtc().toIso8601String(),
      'created_at_utc': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ProjectItem.fromMap(Map<String, dynamic> map) {
    return ProjectItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      colorHex: (map['color_hex'] as String?) ?? '#FFFFFF',
      iconName: (map['icon_name'] as String?) ?? 'folder',
      deadline: map['deadline_utc'] != null
          ? DateTime.parse(map['deadline_utc'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
    );
  }
}
