import 'package:flutter/widgets.dart';

import '../core/l10n/ui_text.dart';

class DmRequestItem {
  DmRequestItem({
    required this.id,
    required this.fromAlias,
    required this.fromAvatarUrl,
    required this.reason,
    required this.timeText,
    required this.status,
    required this.statusLabel,
  });

  final String id;
  final String fromAlias;
  final String fromAvatarUrl;
  final String reason;
  final String timeText;
  final String status;
  final String statusLabel;

  String fromAliasFor(Locale locale) => localizedAlias(locale, fromAlias);

  String statusLabelFor(Locale locale) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return uiTextFor(locale, zh: '已同意', en: 'Accepted');
      case 'rejected':
        return uiTextFor(locale, zh: '已拒绝', en: 'Declined');
      case 'pending':
        return uiTextFor(locale, zh: '待处理', en: 'Pending');
      default:
        return statusLabel;
    }
  }

  String reasonFor(Locale locale) => reason == '请求联系'
      ? uiTextFor(locale, zh: reason, en: 'Wants to reach you')
      : reason;

  factory DmRequestItem.fromJson(Map<String, dynamic> json) {
    return DmRequestItem(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      fromAlias:
          (json['fromAlias'] ?? json['fromName'] ?? json['from'] ?? '匿名同学')
              .toString(),
      fromAvatarUrl:
          (json['fromAvatarUrl'] ?? json['avatarUrl'] ?? '').toString(),
      reason: (json['reason'] ?? json['message'] ?? '请求联系').toString(),
      timeText: (json['timeText'] ?? json['time'] ?? json['createdAt'] ?? '-')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? _statusLabel(json['status']))
          .toString(),
    );
  }

  static String _statusLabel(dynamic status) {
    final String normalized = (status ?? 'pending').toString().toLowerCase();
    switch (normalized) {
      case 'accepted':
        return '已同意';
      case 'rejected':
        return '已拒绝';
      case 'pending':
      default:
        return '待处理';
    }
  }
}
