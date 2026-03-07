class CommentItem {
  CommentItem({
    required this.id,
    required this.authorAlias,
    required this.content,
    required this.createdAt,
    required this.likeCount,
  });

  final String id;
  final String authorAlias;
  final String content;
  final DateTime createdAt;
  final int likeCount;

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final dynamic created = json['createdAt'] ?? json['createTime'];
    DateTime createdAt = DateTime.now();
    if (created is String) {
      createdAt = DateTime.tryParse(created) ?? DateTime.now();
    } else if (created is int) {
      createdAt = created.toString().length <= 10
          ? DateTime.fromMillisecondsSinceEpoch(created * 1000)
          : DateTime.fromMillisecondsSinceEpoch(created);
    }

    return CommentItem(
      id: (json['id'] ?? json['commentId'] ?? '').toString(),
      authorAlias: (json['authorAlias'] ?? json['anonymousName'] ?? '匿名同学').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: createdAt,
      likeCount: _toInt(json['likeCount']) ?? 0,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
