import 'package:flutter/widgets.dart';

import '../core/l10n/ui_text.dart';

class ReportItem {
  ReportItem({
    required this.id,
    required this.target,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.reason,
    required this.description,
    required this.status,
    required this.result,
    required this.createdAt,
    required this.handledAt,
  });

  final String id;
  final String target;
  final String targetType;
  final String targetId;
  final String targetTitle;
  final String reason;
  final String description;
  final String status;
  final String result;
  final String createdAt;
  final String handledAt;

  bool get isPending => status.trim().toLowerCase() == 'pending';

  /// The server stores pending, resolved or misreport; older rows may hold
  /// a label already, which is shown as is.
  String statusLabelFor(Locale locale) => switch (status.trim().toLowerCase()) {
    'pending' => uiTextFor(locale, zh: '待处理', en: 'Pending'),
    'resolved' => uiTextFor(locale, zh: '已处理', en: 'Handled'),
    'misreport' => uiTextFor(locale, zh: '举报未成立', en: 'Not upheld'),
    _ => status,
  };

  String targetTypeLabelFor(Locale locale) =>
      switch (targetType.trim().toLowerCase()) {
        'post' => uiTextFor(locale, zh: '帖子', en: 'Post'),
        'comment' => uiTextFor(locale, zh: '评论', en: 'Comment'),
        'user' => uiTextFor(locale, zh: '用户', en: 'User'),
        'message' => uiTextFor(locale, zh: '私信', en: 'Message'),
        _ => uiTextFor(locale, zh: '内容', en: 'Content'),
      };

  /// 帖子「标题」, or just the type when the target is gone.
  String targetLabelFor(Locale locale) {
    final String title = targetTitle.trim();
    final String type = targetTypeLabelFor(locale);
    return title.isEmpty ? type : '$type「$title」';
  }

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    final String targetType = (json['targetType'] ?? '').toString();
    final String targetId = (json['targetId'] ?? '').toString();
    final String fallbackTarget = targetType.isNotEmpty || targetId.isNotEmpty
        ? '$targetType: $targetId'
        : '-';
    return ReportItem(
      id: (json['id'] ?? json['reportId'] ?? '').toString(),
      target: (json['target'] ?? json['targetName'] ?? fallbackTarget)
          .toString(),
      targetType: targetType,
      targetId: targetId,
      targetTitle: (json['targetTitle'] ?? '').toString(),
      reason: (json['reason'] ?? '-').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? json['result'] ?? '-').toString(),
      result: (json['result'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
    );
  }
}
