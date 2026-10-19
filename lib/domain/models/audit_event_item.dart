class AuditEventItem {
  final String id;
  final String eventType; // 'SCHEDULED', 'DELIVERED', 'SNOOZED', 'COMPLETED', 'DISMISSED', 'RECONCILED'
  final String? ownerId;
  final String title;
  final String details;
  final DateTime createdAt;

  const AuditEventItem({
    required this.id,
    required this.eventType,
    this.ownerId,
    required this.title,
    this.details = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_type': eventType,
      'owner_id': ownerId,
      'title': title,
      'details': details,
      'created_at_utc': createdAt.toUtc().toIso8601String(),
    };
  }

  factory AuditEventItem.fromMap(Map<String, dynamic> map) {
    return AuditEventItem(
      id: map['id'] as String,
      eventType: map['event_type'] as String,
      ownerId: map['owner_id'] as String?,
      title: map['title'] as String,
      details: (map['details'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at_utc'] as String).toLocal(),
    );
  }
}
