enum PostStatus {
  ongoing,
  resolved,
  closed,
}

extension PostStatusLabel on PostStatus {
  String get label {
    switch (this) {
      case PostStatus.ongoing:
        return '进行中';
      case PostStatus.resolved:
        return '已解决';
      case PostStatus.closed:
        return '已结束';
    }
  }
}

extension PostStatusCodec on PostStatus {
  String get apiValue {
    switch (this) {
      case PostStatus.ongoing:
        return 'ongoing';
      case PostStatus.resolved:
        return 'resolved';
      case PostStatus.closed:
        return 'closed';
    }
  }

  static PostStatus fromDynamic(dynamic value) {
    final String text = value?.toString().toLowerCase().trim() ?? '';
    if (text == 'resolved' || text == 'solved' || text == '已解决') {
      return PostStatus.resolved;
    }
    if (text == 'closed' ||
        text == 'ended' ||
        text == 'finished' ||
        text == '已结束') {
      return PostStatus.closed;
    }
    return PostStatus.ongoing;
  }
}

class PostItem {
  PostItem({
    required this.id,
    required this.title,
    required this.content,
    required this.channel,
    required this.tags,
    required this.authorAlias,
    required this.createdAt,
    required this.hasImage,
    required this.commentCount,
    required this.likeCount,
    required this.favoriteCount,
    required this.status,
    required this.allowComment,
    required this.allowDm,
    this.canMessageAuthor = false,
    this.isOwnPost = false,
    this.isFavorited = false,
  });

  final String id;
  final String title;
  final String content;
  final String channel;
  final List<String> tags;
  final String authorAlias;
  final DateTime createdAt;
  final bool hasImage;
  final int commentCount;
  final int likeCount;
  final int favoriteCount;
  final PostStatus status;
  final bool allowComment;
  final bool allowDm;
  final bool canMessageAuthor;
  final bool isOwnPost;
  final bool isFavorited;

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final dynamic tagsValue = json['tags'] ?? json['tagList'];
    final dynamic imagesValue = json['images'] ?? json['imageList'];

    return PostItem(
      id: _str(json, <String>['id', 'postId']) ?? '',
      title: _str(json, <String>['title']) ?? '',
      content: _str(json, <String>['content', 'body']) ?? '',
      channel: _str(json, <String>['channel', 'channelName']) ?? '未分类',
      tags: _toStringList(tagsValue),
      authorAlias:
          _str(json, <String>['authorAlias', 'anonymousName', 'alias']) ??
              '匿名同学',
      createdAt:
          _date(json, <String>['createdAt', 'createTime', 'publishTime']) ??
              DateTime.now(),
      hasImage: _bool(json, <String>['hasImage']) ??
          (imagesValue is List ? imagesValue.isNotEmpty : false),
      commentCount: _int(json, <String>['commentCount', 'commentsCount']) ?? 0,
      likeCount: _int(json, <String>['likeCount', 'likes']) ?? 0,
      favoriteCount: _int(json, <String>['favoriteCount', 'collectCount']) ?? 0,
      status: PostStatusCodec.fromDynamic(json['status']),
      allowComment: _bool(json, <String>['allowComment']) ?? true,
      allowDm: _bool(json, <String>['allowDm', 'allowDirectMessage']) ?? false,
      canMessageAuthor:
          _bool(json, <String>['canMessageAuthor', 'canContactAuthor']) ??
              false,
      isOwnPost: _bool(json, <String>['isOwnPost']) ?? false,
      isFavorited: _bool(json, <String>['favorited', 'isFavorited']) ?? false,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'channel': channel,
      'tags': tags,
      'status': status.apiValue,
      'allowComment': allowComment,
      'allowDm': allowDm,
      'hasImage': hasImage,
    };
  }

  PostItem copyWith({
    String? id,
    String? title,
    String? content,
    String? channel,
    List<String>? tags,
    String? authorAlias,
    DateTime? createdAt,
    bool? hasImage,
    int? commentCount,
    int? likeCount,
    int? favoriteCount,
    PostStatus? status,
    bool? allowComment,
    bool? allowDm,
    bool? canMessageAuthor,
    bool? isOwnPost,
    bool? isFavorited,
  }) {
    return PostItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      channel: channel ?? this.channel,
      tags: tags ?? this.tags,
      authorAlias: authorAlias ?? this.authorAlias,
      createdAt: createdAt ?? this.createdAt,
      hasImage: hasImage ?? this.hasImage,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      status: status ?? this.status,
      allowComment: allowComment ?? this.allowComment,
      allowDm: allowDm ?? this.allowDm,
      canMessageAuthor: canMessageAuthor ?? this.canMessageAuthor,
      isOwnPost: isOwnPost ?? this.isOwnPost,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }

  static String? _str(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null) {
        final String text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static bool? _bool(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
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
    }
    return null;
  }

  static DateTime? _date(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value is DateTime) {
        return value;
      }
      if (value is int) {
        if (value.toString().length <= 10) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
