// Admin feedback (信箱) models

part of '../admin_models.dart';

/// One row of GET /api/admin/feedbacks.
class AdminFeedbackEntry {
  AdminFeedbackEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userNickname,
    required this.studentId,
    required this.userDeleted,
    required this.category,
    required this.content,
    required this.contact,
    required this.status,
    required this.schoolReply,
    required this.createdAt,
    required this.handledAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String userNickname;
  final String studentId;
  final bool userDeleted;
  final String category;
  final String content;
  final String contact;

  /// pending, resolved (已回复) or closed.
  final String status;
  final String schoolReply;
  final String createdAt;
  final String handledAt;

  factory AdminFeedbackEntry.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    final String status = (json['status'] ?? '').toString();
    final Object? content = json['content'];
    if (id.isEmpty || status.isEmpty || content is! String) {
      throw const FormatException('反馈列表响应格式无效');
    }
    return AdminFeedbackEntry(
      id: id,
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      userDeleted: json['userDeleted'] == true,
      category: (json['category'] ?? '').toString(),
      content: content,
      contact: (json['contact'] ?? '').toString(),
      status: status,
      schoolReply: (json['schoolReply'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
    );
  }
}
