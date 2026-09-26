// Admin system configuration models

part of '../admin_models.dart';

/// GET /admin/channels-tags. Sections replaced channels, so only tags are
/// managed here.
class AdminTagData {
  AdminTagData({required this.tags});

  final List<String> tags;

  factory AdminTagData.fromJson(Map<String, dynamic> json) {
    final dynamic tags = json['tags'];
    if (tags is! List) {
      throw const FormatException('标签列表响应缺少 tags');
    }
    return AdminTagData(tags: _toStringList(tags));
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
    final dynamic rawSettings = json['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('系统配置响应缺少 settings');
    }
    final Map<String, dynamic> settings = rawSettings.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
    int requireInt(String key) {
      final int? value = _toInt(settings[key]);
      if (value == null) {
        throw FormatException('系统配置响应缺少 $key');
      }
      return value;
    }

    return AdminSystemConfig(
      sensitiveWords: _toStringList(json['sensitiveWords']),
      postRateLimit: requireInt('postRateLimit'),
      commentRateLimit: requireInt('commentRateLimit'),
      messageRateLimit: requireInt('messageRateLimit'),
      imageMaxMb: requireInt('imageMaxMB'),
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
