class ConversationItem {
  ConversationItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.timeText,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final String timeText;

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: (json['id'] ?? json['conversationId'] ?? '').toString(),
      name: (json['name'] ?? json['peerAlias'] ?? '匿名同学').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['peerAvatarUrl'] ?? '').toString(),
      lastMessage:
          (json['lastMessage'] ?? json['contentPreview'] ?? '-').toString(),
      timeText: (json['timeText'] ?? json['time'] ?? json['updatedAt'] ?? '-')
          .toString(),
    );
  }
}
