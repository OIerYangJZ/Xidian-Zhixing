class CommentItem {
  CommentItem({
    required this.id,
    required this.authorAlias,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    this.authorAvatar,
    this.isLiked = false,
    this.isPinned = false,
    this.parentId = '',
    this.replies = const [],
    this.authorUserId = '',
  });

  final String id;
  final String authorAlias;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final String? authorAvatar;
  final bool isLiked;
  final bool isPinned;
  final String parentId;
  final List<CommentItem> replies;
  final String authorUserId;

  /// 兼容旧字段：authorNickname = authorAlias
  String get authorNickname => authorAlias;

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

    final dynamic rawReplies = json['replies'];
    final List<CommentItem> parsedReplies = <CommentItem>[];
    if (rawReplies is List) {
      for (final dynamic reply in rawReplies) {
        if (reply is Map<String, dynamic>) {
          parsedReplies.add(CommentItem.fromJson(reply));
        } else if (reply is Map) {
          parsedReplies.add(
            CommentItem.fromJson(
              reply.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, dynamic>(key.toString(), value),
              ),
            ),
          );
        }
      }
    }

    return CommentItem(
      id: (json['id'] ?? json['commentId'] ?? '').toString(),
      authorAlias:
          (json['authorAlias'] ?? json['anonymousName'] ?? '匿名同学').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: createdAt,
      likeCount: _toInt(json['likeCount']) ?? 0,
      authorAvatar: (json['authorAvatar'] ??
              json['authorAvatarUrl'] ??
              json['avatar'] ??
              '')
          .toString(),
      isLiked: _toBool(json['isLiked'] ?? json['liked']) ?? false,
      isPinned: _toBool(json['isPinned'] ?? json['pinned']) ?? false,
      parentId: (json['parentId'] ?? '').toString(),
      replies: parsedReplies,
      authorUserId: (json['authorUserId'] ?? json['authorId'] ?? '').toString(),
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
