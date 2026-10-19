class EventItem {
  final String id;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isAllDay;
  final String? location;
  final String colorHex;
  final DateTime createdAt;

  const EventItem({
    required this.id,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    this.isAllDay = false,
    this.location,
    this.colorHex = '#FF3B30',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'starts_at_utc': startsAt.toUtc().toIso8601String(),
      'ends_at_utc': endsAt.toUtc().toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'location': location,
      'color_hex': colorHex,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
    };
  }

  factory EventItem.fromMap(Map<String, dynamic> map) {
    return EventItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startsAt: DateTime.parse(map['starts_at_utc'] as String).toLocal(),
      endsAt: DateTime.parse(map['ends_at_utc'] as String).toLocal(),
      isAllDay: (map['is_all_day'] as int? ?? 0) == 1,
      location: map['location'] as String?,
      colorHex: map['color_hex'] as String? ?? '#FF3B30',
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
    );
  }

  EventItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isAllDay,
    String? location,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
