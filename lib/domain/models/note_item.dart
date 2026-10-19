class NoteItem {
  final String id;
  final String title;
  final String content;
  final String tags;
  final String? linkedEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteItem({
    required this.id,
    required this.title,
    this.content = '',
    this.tags = '',
    this.linkedEntityId,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteItem copyWith({
    String? id,
    String? title,
    String? content,
    String? tags,
    String? linkedEntityId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'linked_entity_id': linkedEntityId,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
      'updated_at_utc': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    return NoteItem(
      id: map['id'] as String,
      title: map['title'] as String,
      content: (map['content'] as String?) ?? '',
      tags: (map['tags'] as String?) ?? '',
      linkedEntityId: map['linked_entity_id'] as String?,
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at_utc'] as String).toLocal(),
    );
  }
}
