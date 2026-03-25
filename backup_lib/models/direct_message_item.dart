class DirectMessageItem {
  DirectMessageItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.timeText,
    required this.fromMe,
    required this.senderAlias,
    this.isRead = false,
    this.readAt = '',
    this.deliveryStatus = 'sent',
  });

  final String id;
  final String content;
  final String createdAt;
  final String timeText;
  final bool fromMe;
  final String senderAlias;
  final bool isRead;
  final String readAt;
  final String deliveryStatus;

  factory DirectMessageItem.fromJson(Map<String, dynamic> json) {
    final String readAt = (json['readAt'] ?? '').toString();
    final bool isRead = _toBool(json['isRead']) ?? readAt.trim().isNotEmpty;
    return DirectMessageItem(
      id: (json['id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      timeText: (json['timeText'] ?? json['createdAt'] ?? '-').toString(),
      fromMe: _toBool(json['fromMe']) ?? false,
      senderAlias: (json['senderAlias'] ?? '匿名同学').toString(),
      isRead: isRead,
      readAt: readAt,
      deliveryStatus:
          (json['deliveryStatus'] ?? (isRead ? 'read' : 'sent')).toString(),
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
      final String normalized = value.toLowerCase().trim();
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
