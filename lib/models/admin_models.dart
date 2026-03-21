class AdminOverview {
  AdminOverview({
    required this.todayNewUsers,
    required this.todayPosts,
    required this.todayComments,
    required this.todayReports,
    required this.pendingReviews,
    required this.pendingCancellationRequests,
    required this.activeUsers,
    required this.bannedUsers,
    required this.mutedUsers,
  });

  final int todayNewUsers;
  final int todayPosts;
  final int todayComments;
  final int todayReports;
  final int pendingReviews;
  final int pendingCancellationRequests;
  final int activeUsers;
  final int bannedUsers;
  final int mutedUsers;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      todayNewUsers: _toInt(json['todayNewUsers']) ?? 0,
      todayPosts: _toInt(json['todayPosts']) ?? 0,
      todayComments: _toInt(json['todayComments']) ?? 0,
      todayReports: _toInt(json['todayReports']) ?? 0,
      pendingReviews: _toInt(json['pendingReviews']) ?? 0,
      pendingCancellationRequests:
          _toInt(json['pendingCancellationRequests']) ?? 0,
      activeUsers: _toInt(json['activeUsers']) ?? 0,
      bannedUsers: _toInt(json['bannedUsers']) ?? 0,
      mutedUsers: _toInt(json['mutedUsers']) ?? 0,
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
    required this.authorUserId,
    required this.authorNickname,
    required this.authorEmail,
    required this.authorStudentId,
    required this.createdAt,
    required this.reviewStatus,
    required this.riskMarked,
  });

  final String id;
  final String targetType;
  final String title;
  final String content;
  final String authorAlias;
  final String authorUserId;
  final String authorNickname;
  final String authorEmail;
  final String authorStudentId;
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
      authorUserId: (json['authorUserId'] ?? '').toString(),
      authorNickname:
          (json['authorNickname'] ?? json['authorAlias'] ?? '匿名同学').toString(),
      authorEmail: (json['authorEmail'] ?? '').toString(),
      authorStudentId: (json['authorStudentId'] ?? '').toString(),
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
    required this.studentId,
    required this.alias,
    required this.avatarUrl,
    required this.verified,
    required this.banned,
    required this.muted,
    required this.deleted,
    required this.postCount,
    required this.commentCount,
    required this.reportCount,
    required this.createdAt,
    required this.hasPendingCancellationRequest,
    required this.hasPendingAppeal,
  });

  final String id;
  final String email;
  final String studentId;
  final String alias;
  final String avatarUrl;
  final bool verified;
  final bool banned;
  final bool muted;
  final bool deleted;
  final int postCount;
  final int commentCount;
  final int reportCount;
  final String createdAt;
  final bool hasPendingCancellationRequest;
  final bool hasPendingAppeal;

  factory AdminUserEntry.fromJson(Map<String, dynamic> json) {
    return AdminUserEntry(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      alias: (json['alias'] ?? '匿名同学').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      verified: _toBool(json['verified']) ?? false,
      banned: _toBool(json['banned']) ?? false,
      muted: _toBool(json['muted']) ?? false,
      deleted: _toBool(json['deleted']) ?? false,
      postCount: _toInt(json['postCount']) ?? 0,
      commentCount: _toInt(json['commentCount']) ?? 0,
      reportCount: _toInt(json['reportCount']) ?? 0,
      createdAt: (json['createdAt'] ?? '').toString(),
      hasPendingCancellationRequest:
          _toBool(json['hasPendingCancellationRequest']) ?? false,
      hasPendingAppeal: _toBool(json['hasPendingAppeal']) ?? false,
    );
  }
}

class AdminAccountCancellationRequest {
  AdminAccountCancellationRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userNickname,
    required this.studentId,
    required this.avatarUrl,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.reviewNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String userNickname;
  final String studentId;
  final String avatarUrl;
  final String reason;
  final String status;
  final String statusLabel;
  final String reviewNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;

  factory AdminAccountCancellationRequest.fromJson(Map<String, dynamic> json) {
    return AdminAccountCancellationRequest(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待审核').toString(),
      reviewNote: (json['reviewNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
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

class AdminSystemAnnouncement {
  AdminSystemAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.timeText,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String content;
  final String createdAt;
  final String timeText;
  final String createdBy;

  factory AdminSystemAnnouncement.fromJson(Map<String, dynamic> json) {
    return AdminSystemAnnouncement(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      timeText: (json['timeText'] ?? json['createdAt'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
    );
  }
}

class AdminAppealEntry {
  AdminAppealEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.studentId,
    required this.userNickname,
    required this.appealType,
    required this.appealTypeLabel,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.content,
    required this.status,
    required this.statusLabel,
    required this.adminNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
    required this.userDeleted,
    required this.userBanned,
    required this.userMuted,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String studentId;
  final String userNickname;
  final String appealType;
  final String appealTypeLabel;
  final String targetType;
  final String targetId;
  final String title;
  final String content;
  final String status;
  final String statusLabel;
  final String adminNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;
  final bool userDeleted;
  final bool userBanned;
  final bool userMuted;

  factory AdminAppealEntry.fromJson(Map<String, dynamic> json) {
    return AdminAppealEntry(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      appealType: (json['appealType'] ?? 'other').toString(),
      appealTypeLabel: (json['appealTypeLabel'] ?? '其他申诉').toString(),
      targetType: (json['targetType'] ?? '').toString(),
      targetId: (json['targetId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待处理').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
      userDeleted: _toBool(json['userDeleted']) ?? false,
      userBanned: _toBool(json['userBanned']) ?? false,
      userMuted: _toBool(json['userMuted']) ?? false,
    );
  }
}

class AdminExportFile {
  AdminExportFile({
    required this.fileName,
    required this.contentType,
    required this.content,
    required this.rowCount,
  });

  final String fileName;
  final String contentType;
  final String content;
  final int rowCount;

  factory AdminExportFile.fromJson(Map<String, dynamic> json) {
    return AdminExportFile(
      fileName: (json['fileName'] ?? 'admin-export.txt').toString(),
      contentType:
          (json['contentType'] ?? 'text/plain; charset=utf-8').toString(),
      content: (json['content'] ?? '').toString(),
      rowCount: _toInt(json['rowCount']) ?? 0,
    );
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
