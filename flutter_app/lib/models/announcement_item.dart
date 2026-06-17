import '../core/network/json_utils.dart';

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.aiSummary,
    required this.publishedAt,
    required this.publisher,
    required this.sourceName,
    required this.type,
    required this.isImportant,
    required this.originalUrl,
  });

  final String id;
  final String title;
  final String content;
  final String summary;
  final String aiSummary;
  final DateTime? publishedAt;
  final String publisher;
  final String sourceName;
  final String type;
  final bool isImportant;
  final String originalUrl;

  String get displaySummary => aiSummary.trim().isNotEmpty ? aiSummary : summary;
  String get displayType => type.trim().isNotEmpty ? type : sourceName;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: readString(json, <String>['id']) ?? '',
      title: readString(json, <String>['title']) ?? '',
      content: readString(json, <String>['content']) ?? '',
      summary: readString(json, <String>['summary']) ?? '',
      aiSummary: readString(json, <String>['aiSummary']) ?? '',
      publishedAt: parseDateTime(json['publishedAt'] ?? json['createdAt']),
      publisher: readString(json, <String>['publisher']) ?? '',
      sourceName: readString(json, <String>['sourceName']) ?? '',
      type: readString(json, <String>['type']) ?? '',
      isImportant: readBool(json, <String>['isImportant']) ?? false,
      originalUrl: readString(json, <String>['originalUrl']) ?? '',
    );
  }
}

class AnnouncementFilters {
  const AnnouncementFilters({required this.types});

  final List<String> types;

  factory AnnouncementFilters.fromJson(Map<String, dynamic> json) {
    return AnnouncementFilters(
      types: asList(json['types'])
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class DailyAnnouncementSummary {
  const DailyAnnouncementSummary({
    required this.title,
    required this.summary,
  });

  final String title;
  final String summary;

  factory DailyAnnouncementSummary.fromJson(Map<String, dynamic> json) {
    return DailyAnnouncementSummary(
      title: readString(json, <String>['title']) ?? '',
      summary: readString(json, <String>['summary', 'answer']) ?? '',
    );
  }
}
