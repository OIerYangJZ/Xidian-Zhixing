class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.relatedType,
    required this.relatedId,
    required this.postId,
    required this.actorId,
    required this.actorAlias,
    required this.createdAt,
    required this.timeText,
    required this.isRead,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String content;
  final String relatedType;
  final String relatedId;
  final String postId;
  final String actorId;
  final String actorAlias;
  final String createdAt;
  final String timeText;
  final bool isRead;
  final String readAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final String readAt = (json['readAt'] ?? '').toString();
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'system').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      relatedType: (json['relatedType'] ?? '').toString(),
      relatedId: (json['relatedId'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      actorId: (json['actorId'] ?? '').toString(),
      actorAlias: (json['actorAlias'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      timeText: (json['timeText'] ?? json['createdAt'] ?? '').toString(),
      isRead: _toBool(json['isRead']) ?? readAt.trim().isNotEmpty,
      readAt: readAt,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      content: content,
      relatedType: relatedType,
      relatedId: relatedId,
      postId: postId,
      actorId: actorId,
      actorAlias: actorAlias,
      createdAt: createdAt,
      timeText: timeText,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
