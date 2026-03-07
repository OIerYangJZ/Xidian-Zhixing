class AdminOverview {
  AdminOverview({
    required this.todayNewUsers,
    required this.todayPosts,
    required this.todayComments,
    required this.todayReports,
    required this.pendingReviews,
    required this.bannedUsers,
  });

  final int todayNewUsers;
  final int todayPosts;
  final int todayComments;
  final int todayReports;
  final int pendingReviews;
  final int bannedUsers;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      todayNewUsers: _toInt(json['todayNewUsers']) ?? 0,
      todayPosts: _toInt(json['todayPosts']) ?? 0,
      todayComments: _toInt(json['todayComments']) ?? 0,
      todayReports: _toInt(json['todayReports']) ?? 0,
      pendingReviews: _toInt(json['pendingReviews']) ?? 0,
      bannedUsers: _toInt(json['bannedUsers']) ?? 0,
    );
  }
}

class AdminReviewItem {
  AdminReviewItem({
    required this.id,
    required this.targetType,
    required this.title,
    required this.content,
    required this.authorAlias,
    required this.createdAt,
    required this.reviewStatus,
    required this.riskMarked,
  });

  final String id;
  final String targetType;
  final String title;
  final String content;
  final String authorAlias;
  final String createdAt;
  final String reviewStatus;
  final bool riskMarked;

  factory AdminReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminReviewItem(
      id: (json['id'] ?? '').toString(),
      targetType: (json['targetType'] ?? 'post').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      authorAlias: (json['authorAlias'] ?? '匿名同学').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      reviewStatus: (json['reviewStatus'] ?? 'pending').toString(),
      riskMarked: _toBool(json['riskMarked']) ?? false,
    );
  }
}

class AdminReportEntry {
  AdminReportEntry({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.description,
    required this.status,
    required this.result,
    required this.reporterAlias,
    required this.createdAt,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String description;
  final String status;
  final String result;
  final String reporterAlias;
  final String createdAt;

  factory AdminReportEntry.fromJson(Map<String, dynamic> json) {
    return AdminReportEntry(
      id: (json['id'] ?? '').toString(),
      targetType: (json['targetType'] ?? 'other').toString(),
      targetId: (json['targetId'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      result: (json['result'] ?? '').toString(),
      reporterAlias: (json['reporterAlias'] ?? '匿名同学').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class AdminUserEntry {
  AdminUserEntry({
    required this.id,
    required this.email,
    required this.alias,
    required this.verified,
    required this.isAdmin,
    required this.banned,
    required this.muted,
    required this.postCount,
    required this.commentCount,
    required this.reportCount,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String alias;
  final bool verified;
  final bool isAdmin;
  final bool banned;
  final bool muted;
  final int postCount;
  final int commentCount;
  final int reportCount;
  final String createdAt;

  factory AdminUserEntry.fromJson(Map<String, dynamic> json) {
    return AdminUserEntry(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      alias: (json['alias'] ?? '匿名同学').toString(),
      verified: _toBool(json['verified']) ?? false,
      isAdmin: _toBool(json['isAdmin']) ?? false,
      banned: _toBool(json['banned']) ?? false,
      muted: _toBool(json['muted']) ?? false,
      postCount: _toInt(json['postCount']) ?? 0,
      commentCount: _toInt(json['commentCount']) ?? 0,
      reportCount: _toInt(json['reportCount']) ?? 0,
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class AdminImageReviewItem {
  AdminImageReviewItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
    required this.moderationReason,
    required this.reviewNote,
    required this.createdAt,
    required this.postId,
    required this.uploaderId,
    required this.uploaderAlias,
  });

  final String id;
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String status;
  final String moderationReason;
  final String reviewNote;
  final String createdAt;
  final String postId;
  final String uploaderId;
  final String uploaderAlias;

  factory AdminImageReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminImageReviewItem(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      sizeBytes: _toInt(json['sizeBytes']) ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      moderationReason: (json['moderationReason'] ?? '').toString(),
      reviewNote: (json['reviewNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      uploaderId: (json['uploaderId'] ?? '').toString(),
      uploaderAlias: (json['uploaderAlias'] ?? '匿名同学').toString(),
    );
  }
}

class AdminChannelTagData {
  AdminChannelTagData({
    required this.channels,
    required this.tags,
  });

  final List<String> channels;
  final List<String> tags;

  factory AdminChannelTagData.fromJson(Map<String, dynamic> json) {
    return AdminChannelTagData(
      channels: _toStringList(json['channels']),
      tags: _toStringList(json['tags']),
    );
  }
}

class AdminSystemConfig {
  AdminSystemConfig({
    required this.sensitiveWords,
    required this.postRateLimit,
    required this.commentRateLimit,
    required this.messageRateLimit,
    required this.imageMaxMb,
  });

  final List<String> sensitiveWords;
  final int postRateLimit;
  final int commentRateLimit;
  final int messageRateLimit;
  final int imageMaxMb;

  factory AdminSystemConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> settings =
        (json['settings'] is Map<String, dynamic>)
            ? json['settings'] as Map<String, dynamic>
            : ((json['settings'] is Map)
                ? (json['settings'] as Map<dynamic, dynamic>).map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  )
                : <String, dynamic>{});

    return AdminSystemConfig(
      sensitiveWords: _toStringList(json['sensitiveWords']),
      postRateLimit: _toInt(settings['postRateLimit']) ??
          _toInt(json['postRateLimit']) ??
          10,
      commentRateLimit: _toInt(settings['commentRateLimit']) ??
          _toInt(json['commentRateLimit']) ??
          30,
      messageRateLimit: _toInt(settings['messageRateLimit']) ??
          _toInt(json['messageRateLimit']) ??
          40,
      imageMaxMb:
          _toInt(settings['imageMaxMB']) ?? _toInt(json['imageMaxMB']) ?? 5,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return <String, dynamic>{
      'sensitiveWords': sensitiveWords,
      'settings': <String, dynamic>{
        'postRateLimit': postRateLimit,
        'commentRateLimit': commentRateLimit,
        'messageRateLimit': messageRateLimit,
        'imageMaxMB': imageMaxMb,
      },
    };
  }
}

int? _toInt(dynamic value) {
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

bool? _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1') {
      return true;
    }
    if (lower == 'false' || lower == '0') {
      return false;
    }
  }
  return null;
}

List<String> _toStringList(dynamic value) {
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
