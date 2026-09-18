import 'package:flutter/widgets.dart';

import '../core/l10n/ui_text.dart';

/// Level and review-status labels arrive from the server already rendered in
/// Chinese, so the UI derives its own label from the structured field instead
/// of echoing `userLevelLabel` / `statusLabel`.
String userLevelLabelForLevel(Locale locale, int level) {
  return level == 1
      ? uiTextFor(locale, zh: '一级用户', en: 'Level 1 user')
      : uiTextFor(locale, zh: '二级用户', en: 'Level 2 user');
}

String reviewStatusLabelFor(
  Locale locale,
  String status, {
  required String pendingZh,
  required String pendingEn,
  required String fallback,
}) {
  switch (status.trim().toLowerCase()) {
    case 'pending':
      return uiTextFor(locale, zh: pendingZh, en: pendingEn);
    case 'approved':
      return uiTextFor(locale, zh: '已通过', en: 'Approved');
    case 'rejected':
      return uiTextFor(locale, zh: '已驳回', en: 'Rejected');
    case 'closed':
      return uiTextFor(locale, zh: '已关闭', en: 'Closed');
    default:
      return fallback;
  }
}

class UserProfile {
  UserProfile({
    required this.nickname,
    required this.studentId,
    required this.avatarUrl,
    required this.email,
    required this.verified,
    required this.verifiedAt,
    required this.banned,
    required this.allowStrangerDm,
    required this.showContactable,
    required this.favoriteCount,
    required this.userLevel,
    required this.userLevelLabel,
    required this.isLevelOneUser,
    required this.isAdmin,
    required this.levelUpgradeRequest,
    required this.accountCancellationRequest,
    this.notifyComment = true,
    this.notifyReply = true,
    this.notifyLike = true,
    this.notifyFavorite = true,
    this.notifyReportResult = true,
    this.notifySystem = true,
    this.userId = '',
    this.postCount = 0,
    this.followingCount = 0,
    this.followerCount = 0,
    this.isFollowing = false,
    this.isFollower = false,
    this.isOwnProfile = false,
    this.canFollow = false,
    this.canDirectMessage = false,
    this.bio = '',
    this.backgroundImageUrl = '',
    this.gender = '',
  });

  final String nickname;
  final String studentId;
  final String avatarUrl;
  final String email;
  final bool verified;
  final String verifiedAt;
  /// Server-side account state. A banned profile is still readable by its
  /// owner so the app can show the appeal screen after a reload.
  final bool banned;
  final bool allowStrangerDm;
  final bool showContactable;
  final bool notifyComment;
  final bool notifyReply;
  final bool notifyLike;
  final bool notifyFavorite;
  final bool notifyReportResult;
  final bool notifySystem;
  final int favoriteCount;
  final int userLevel;
  final String userLevelLabel;
  final bool isLevelOneUser;
  final bool isAdmin;
  final UserLevelRequestSummary? levelUpgradeRequest;
  final AccountCancellationRequestSummary? accountCancellationRequest;
  final String userId;
  final int postCount;
  final int followingCount;
  final int followerCount;
  final bool isFollowing;
  final bool isFollower;
  final bool isOwnProfile;
  final bool canFollow;
  final bool canDirectMessage;
  final String bio;
  final String backgroundImageUrl;
  final String gender;

  bool get isMutual => isFollowing && isFollower;

  String userLevelLabelFor(Locale locale) =>
      userLevelLabelForLevel(locale, isLevelOneUser ? 1 : userLevel);

  String nicknameFor(Locale locale) => localizedAlias(locale, nickname);

  String genderFor(Locale locale) {
    switch (gender) {
      case '男':
        return uiTextFor(locale, zh: gender, en: 'Male');
      case '女':
        return uiTextFor(locale, zh: gender, en: 'Female');
      default:
        return gender;
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final String nickname =
        (json['nickname'] ?? json['alias'] ?? json['anonymousAlias'] ?? '匿名同学')
            .toString();
    return UserProfile(
      nickname: nickname,
      studentId: (json['studentId'] ?? json['userId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      verified: _toBool(json['verified']) ?? true,
      verifiedAt: (json['verifiedAt'] ?? json['verifyTime'] ?? '-').toString(),
      banned: _toBool(json['banned']) ?? false,
      allowStrangerDm: _toBool(json['allowStrangerDm']) ?? true,
      showContactable: _toBool(json['showContactable']) ?? true,
      notifyComment: _toBool(json['notifyComment']) ?? true,
      notifyReply: _toBool(json['notifyReply']) ?? true,
      notifyLike: _toBool(json['notifyLike']) ?? true,
      notifyFavorite: _toBool(json['notifyFavorite']) ?? true,
      notifyReportResult: _toBool(json['notifyReportResult']) ?? true,
      notifySystem: _toBool(json['notifySystem']) ?? true,
      favoriteCount: _toInt(json['favoriteCount']) ?? 0,
      userLevel: _toInt(json['userLevel']) ?? 2,
      userLevelLabel: (json['userLevelLabel'] ?? '二级用户').toString(),
      isLevelOneUser: _toBool(json['isLevelOneUser']) ?? false,
      isAdmin: _toBool(json['isAdmin']) ?? false,
      levelUpgradeRequest: json['levelUpgradeRequest'] is Map
          ? UserLevelRequestSummary.fromJson(
              (json['levelUpgradeRequest'] as Map<dynamic, dynamic>).map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      accountCancellationRequest: json['accountCancellationRequest'] is Map
          ? AccountCancellationRequestSummary.fromJson(
              (json['accountCancellationRequest'] as Map<dynamic, dynamic>).map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      userId: (json['id'] ?? json['userId'] ?? '').toString(),
      postCount: _toInt(json['postCount']) ?? 0,
      followingCount: _toInt(json['followingCount']) ?? 0,
      followerCount: _toInt(json['followerCount']) ?? 0,
      isFollowing: _toBool(json['isFollowing']) ?? false,
      isFollower: _toBool(json['isFollower']) ?? false,
      isOwnProfile: _toBool(json['isOwnProfile']) ?? false,
      canFollow: _toBool(json['canFollow']) ?? false,
      canDirectMessage: _toBool(json['canDirectMessage']) ?? false,
      bio: (json['bio'] ?? json['signature'] ?? '').toString(),
      backgroundImageUrl:
          (json['backgroundImageUrl'] ?? json['backgroundImage'] ?? '')
              .toString(),
      gender: (json['gender'] ?? '').toString(),
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? studentId,
    String? avatarUrl,
    String? email,
    bool? allowStrangerDm,
    bool? showContactable,
    bool? notifyComment,
    bool? notifyReply,
    bool? notifyLike,
    bool? notifyFavorite,
    bool? notifyReportResult,
    bool? notifySystem,
    int? favoriteCount,
    int? userLevel,
    String? userLevelLabel,
    bool? isLevelOneUser,
    bool? isAdmin,
    UserLevelRequestSummary? levelUpgradeRequest,
    AccountCancellationRequestSummary? accountCancellationRequest,
    String? userId,
    int? postCount,
    int? followingCount,
    int? followerCount,
    bool? isFollowing,
    bool? isFollower,
    bool? isOwnProfile,
    bool? canFollow,
    bool? canDirectMessage,
    String? bio,
    String? backgroundImageUrl,
    String? gender,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      studentId: studentId ?? this.studentId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      verified: verified,
      verifiedAt: verifiedAt,
      banned: banned,
      allowStrangerDm: allowStrangerDm ?? this.allowStrangerDm,
      showContactable: showContactable ?? this.showContactable,
      notifyComment: notifyComment ?? this.notifyComment,
      notifyReply: notifyReply ?? this.notifyReply,
      notifyLike: notifyLike ?? this.notifyLike,
      notifyFavorite: notifyFavorite ?? this.notifyFavorite,
      notifyReportResult: notifyReportResult ?? this.notifyReportResult,
      notifySystem: notifySystem ?? this.notifySystem,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      userLevel: userLevel ?? this.userLevel,
      userLevelLabel: userLevelLabel ?? this.userLevelLabel,
      isLevelOneUser: isLevelOneUser ?? this.isLevelOneUser,
      isAdmin: isAdmin ?? this.isAdmin,
      levelUpgradeRequest: levelUpgradeRequest ?? this.levelUpgradeRequest,
      accountCancellationRequest:
          accountCancellationRequest ?? this.accountCancellationRequest,
      userId: userId ?? this.userId,
      postCount: postCount ?? this.postCount,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      canFollow: canFollow ?? this.canFollow,
      canDirectMessage: canDirectMessage ?? this.canDirectMessage,
      bio: bio ?? this.bio,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      gender: gender ?? this.gender,
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
      final String lowered = value.toLowerCase();
      if (lowered == 'true' || lowered == '1') {
        return true;
      }
      if (lowered == 'false' || lowered == '0') {
        return false;
      }
    }
    return null;
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

class AccountCancellationRequestSummary {
  AccountCancellationRequestSummary({
    required this.id,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.reviewNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
  });

  final String id;
  final String reason;
  final String status;
  final String statusLabel;
  final String reviewNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;

  String statusLabelFor(Locale locale) => reviewStatusLabelFor(
    locale,
    status,
    pendingZh: '待审核',
    pendingEn: 'Pending review',
    fallback: statusLabel,
  );

  factory AccountCancellationRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return AccountCancellationRequestSummary(
      id: (json['id'] ?? '').toString(),
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

class UserLevelRequestSummary {
  UserLevelRequestSummary({
    required this.id,
    required this.currentLevel,
    required this.currentLevelLabel,
    required this.targetLevel,
    required this.targetLevelLabel,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.adminNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
  });

  final String id;
  final int currentLevel;
  final String currentLevelLabel;
  final int targetLevel;
  final String targetLevelLabel;
  final String reason;
  final String status;
  final String statusLabel;
  final String adminNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;

  String statusLabelFor(Locale locale) => reviewStatusLabelFor(
    locale,
    status,
    pendingZh: '待处理',
    pendingEn: 'Pending',
    fallback: statusLabel,
  );

  String currentLevelLabelFor(Locale locale) =>
      userLevelLabelForLevel(locale, currentLevel);

  String targetLevelLabelFor(Locale locale) =>
      userLevelLabelForLevel(locale, targetLevel);

  factory UserLevelRequestSummary.fromJson(Map<String, dynamic> json) {
    return UserLevelRequestSummary(
      id: (json['id'] ?? '').toString(),
      currentLevel: UserProfile._toInt(json['currentLevel']) ?? 2,
      currentLevelLabel: (json['currentLevelLabel'] ?? '二级用户').toString(),
      targetLevel: UserProfile._toInt(json['targetLevel']) ?? 1,
      targetLevelLabel: (json['targetLevelLabel'] ?? '一级用户').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待处理').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
    );
  }
}
