import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/l10n/ui_text.dart';

/// A post's 状态, set by its author only and changeable in any direction.
/// Optional: [none] (the default) shows no badge.
enum PostStatus { none, ongoing, resolved, closed }

extension PostStatusLabel on PostStatus {
  String get label {
    switch (this) {
      case PostStatus.none:
        return '不标记';
      case PostStatus.ongoing:
        return '进行中';
      case PostStatus.resolved:
        return '已解决';
      case PostStatus.closed:
        return '已结束';
    }
  }

  String labelFor(Locale locale) {
    switch (this) {
      case PostStatus.none:
        return uiTextFor(locale, zh: '不标记', en: 'No status');
      case PostStatus.ongoing:
        return uiTextFor(locale, zh: '进行中', en: 'Ongoing');
      case PostStatus.resolved:
        return uiTextFor(locale, zh: '已解决', en: 'Resolved');
      case PostStatus.closed:
        return uiTextFor(locale, zh: '已结束', en: 'Closed');
    }
  }
}

extension PostStatusCodec on PostStatus {
  String get apiValue {
    switch (this) {
      case PostStatus.none:
        return 'none';
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
    if (text == 'ongoing' || text == 'open' || text == '进行中') {
      return PostStatus.ongoing;
    }
    return PostStatus.none;
  }
}

class PostItem {
  PostItem({
    required this.id,
    required this.title,
    required this.content,
    this.contentFormat = 'plain',
    this.markdownSource = '',
    this.sectionType = '',
    this.sectionId = '',
    this.sectionName = '',
    required this.tags,
    required this.authorAlias,
    this.authorUserId = '',
    this.authorAvatarUrl = '',
    required this.createdAt,
    required this.hasImage,
    required this.commentCount,
    required this.likeCount,
    required this.favoriteCount,
    this.viewCount = 0,
    required this.status,
    required this.allowComment,
    required this.allowDm,
    this.isAnonymous = false,
    this.isPrivate = false,
    this.isPinned = false,
    this.pinStartedAt,
    this.pinExpiresAt,
    this.pinDurationMinutes = 0,
    this.pinDurationLabel = '',
    this.canMessageAuthor = false,
    this.canViewAuthorProfile = false,
    this.canFollowAuthor = false,
    this.isFollowingAuthor = false,
    this.isOwnPost = false,
    this.isFavorited = false,
    this.isLiked = false,
    this.imageUrls = const <String>[],
    this.uploadedImageIds = const <String>[],
    this.reviewStatus = 'approved',
  });

  final String id;
  final String title;
  final String content;
  final String contentFormat;
  final String markdownSource;

  /// The 分区 the post was filed under (general / college / club). Posts from
  /// before sections carry none and show no section badge.
  final String sectionType;
  final String sectionId;
  final String sectionName;
  final List<String> tags;
  final String authorAlias;
  final String authorUserId;
  final String authorAvatarUrl;
  final DateTime createdAt;
  final bool hasImage;
  final int commentCount;
  final int likeCount;
  final int favoriteCount;
  final int viewCount;
  final PostStatus status;
  final bool allowComment;
  final bool allowDm;
  final bool isAnonymous;
  final bool isPrivate;
  final bool isPinned;
  final DateTime? pinStartedAt;
  final DateTime? pinExpiresAt;
  final int pinDurationMinutes;
  final String pinDurationLabel;
  final bool canMessageAuthor;
  final bool canViewAuthorProfile;
  final bool canFollowAuthor;
  final bool isFollowingAuthor;
  final bool isOwnPost;
  final bool isFavorited;
  final bool isLiked;
  final List<String> imageUrls;
  final List<String> uploadedImageIds;

  /// approved, pending or rejected. Only one's own posts are ever pending or
  /// rejected (待审核 / 未通过审核).
  final String reviewStatus;

  bool get isMarkdown =>
      contentFormat.trim().toLowerCase() == 'markdown' &&
      markdownSource.trim().isNotEmpty;

  String authorAliasFor(Locale locale) => localizedAlias(locale, authorAlias);

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final dynamic tagsValue = json['tags'] ?? json['tagList'];
    final dynamic imagesValue = json['images'] ?? json['imageList'];
    final dynamic imageUrlsValue =
        json['imageUrls'] ?? json['imageList'] ?? json['images'];
    final dynamic uploadedImageIdsValue =
        json['uploadedImageIds'] ?? json['imageIds'] ?? json['uploadIds'];

    return PostItem(
      id: _str(json, <String>['id', 'postId']) ?? '',
      title: _str(json, <String>['title']) ?? '',
      content: _str(json, <String>['content', 'body']) ?? '',
      contentFormat:
          _str(json, <String>['contentFormat'])?.trim().toLowerCase() ==
              'markdown'
          ? 'markdown'
          : 'plain',
      markdownSource: _str(json, <String>['markdownSource']) ?? '',
      sectionType: _str(json, <String>['sectionType']) ?? '',
      sectionId: _str(json, <String>['sectionId']) ?? '',
      sectionName: _str(json, <String>['sectionName']) ?? '',
      tags: _toStringList(tagsValue),
      authorAlias:
          _str(json, <String>['authorAlias', 'anonymousName', 'alias']) ??
          '匿名同学',
      authorUserId: _str(json, <String>['authorUserId', 'authorId']) ?? '',
      authorAvatarUrl: AppConfig.resolveUrl(
        _str(json, <String>['authorAvatarUrl', 'avatarUrl']) ?? '',
      ),
      createdAt:
          _date(json, <String>['createdAt', 'createTime', 'publishTime']) ??
          DateTime.now(),
      hasImage:
          _bool(json, <String>['hasImage']) ??
          (imagesValue is List ? imagesValue.isNotEmpty : false) ||
              (imageUrlsValue is List ? imageUrlsValue.isNotEmpty : false),
      commentCount: _int(json, <String>['commentCount', 'commentsCount']) ?? 0,
      likeCount: _int(json, <String>['likeCount', 'likes']) ?? 0,
      favoriteCount: _int(json, <String>['favoriteCount', 'collectCount']) ?? 0,
      viewCount: _int(json, <String>['viewCount']) ?? 0,
      status: PostStatusCodec.fromDynamic(json['status']),
      allowComment: _bool(json, <String>['allowComment']) ?? true,
      allowDm: _bool(json, <String>['allowDm', 'allowDirectMessage']) ?? false,
      isAnonymous: _bool(json, <String>['isAnonymous']) ?? false,
      isPrivate:
          _bool(json, <String>['isPrivate']) ??
          ((_str(json, <String>['visibility']) ?? 'public') == 'private'),
      isPinned: _bool(json, <String>['isPinned']) ?? false,
      pinStartedAt: _date(json, <String>['pinStartedAt']),
      pinExpiresAt: _date(json, <String>['pinExpiresAt']),
      pinDurationMinutes: _int(json, <String>['pinDurationMinutes']) ?? 0,
      pinDurationLabel: _str(json, <String>['pinDurationLabel']) ?? '',
      canMessageAuthor:
          _bool(json, <String>['canMessageAuthor', 'canContactAuthor']) ??
          false,
      canViewAuthorProfile:
          _bool(json, <String>['canViewAuthorProfile']) ?? false,
      canFollowAuthor: _bool(json, <String>['canFollowAuthor']) ?? false,
      isFollowingAuthor: _bool(json, <String>['isFollowingAuthor']) ?? false,
      isOwnPost: _bool(json, <String>['isOwnPost']) ?? false,
      isFavorited: _bool(json, <String>['favorited', 'isFavorited']) ?? false,
      isLiked: _bool(json, <String>['liked', 'isLiked']) ?? false,
      imageUrls: _toStringList(imageUrlsValue)
          .map(AppConfig.resolveUrl)
          .where((String value) => value.isNotEmpty)
          .toList(),
      uploadedImageIds: _toStringList(uploadedImageIdsValue),
      reviewStatus: (_str(json, <String>['reviewStatus']) ?? 'approved')
          .trim()
          .toLowerCase(),
    );
  }

  PostItem copyWith({
    String? id,
    String? title,
    String? content,
    String? contentFormat,
    String? markdownSource,
    String? sectionType,
    String? sectionId,
    String? sectionName,
    List<String>? tags,
    String? authorAlias,
    String? authorUserId,
    String? authorAvatarUrl,
    DateTime? createdAt,
    bool? hasImage,
    int? commentCount,
    int? likeCount,
    int? favoriteCount,
    int? viewCount,
    PostStatus? status,
    bool? allowComment,
    bool? allowDm,
    bool? isAnonymous,
    bool? isPrivate,
    bool? isPinned,
    DateTime? pinStartedAt,
    DateTime? pinExpiresAt,
    int? pinDurationMinutes,
    String? pinDurationLabel,
    bool? canMessageAuthor,
    bool? canViewAuthorProfile,
    bool? canFollowAuthor,
    bool? isFollowingAuthor,
    bool? isOwnPost,
    bool? isFavorited,
    bool? isLiked,
    List<String>? imageUrls,
    List<String>? uploadedImageIds,
    String? reviewStatus,
  }) {
    return PostItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      contentFormat: contentFormat ?? this.contentFormat,
      markdownSource: markdownSource ?? this.markdownSource,
      sectionType: sectionType ?? this.sectionType,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      tags: tags ?? this.tags,
      authorAlias: authorAlias ?? this.authorAlias,
      authorUserId: authorUserId ?? this.authorUserId,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      hasImage: hasImage ?? this.hasImage,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      viewCount: viewCount ?? this.viewCount,
      status: status ?? this.status,
      allowComment: allowComment ?? this.allowComment,
      allowDm: allowDm ?? this.allowDm,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPrivate: isPrivate ?? this.isPrivate,
      isPinned: isPinned ?? this.isPinned,
      pinStartedAt: pinStartedAt ?? this.pinStartedAt,
      pinExpiresAt: pinExpiresAt ?? this.pinExpiresAt,
      pinDurationMinutes: pinDurationMinutes ?? this.pinDurationMinutes,
      pinDurationLabel: pinDurationLabel ?? this.pinDurationLabel,
      canMessageAuthor: canMessageAuthor ?? this.canMessageAuthor,
      canViewAuthorProfile: canViewAuthorProfile ?? this.canViewAuthorProfile,
      canFollowAuthor: canFollowAuthor ?? this.canFollowAuthor,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      isOwnPost: isOwnPost ?? this.isOwnPost,
      isFavorited: isFavorited ?? this.isFavorited,
      isLiked: isLiked ?? this.isLiked,
      imageUrls: imageUrls ?? this.imageUrls,
      uploadedImageIds: uploadedImageIds ?? this.uploadedImageIds,
      reviewStatus: reviewStatus ?? this.reviewStatus,
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
