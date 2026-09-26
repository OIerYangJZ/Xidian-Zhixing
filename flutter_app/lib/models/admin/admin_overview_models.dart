// Admin overview data models

part of '../admin_models.dart';

class AdminOverview {
  AdminOverview({
    required this.todayNewUsers,
    required this.todayPosts,
    required this.todayComments,
    required this.todayReports,
    required this.pendingReviews,
    required this.pendingCancellationRequests,
    required this.pendingFeedbacks,
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
  final int pendingFeedbacks;
  final int activeUsers;
  final int bannedUsers;
  final int mutedUsers;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    int requireInt(String key) {
      final int? value = _toInt(json[key]);
      if (value == null) {
        throw FormatException('概览响应缺少 $key');
      }
      return value;
    }

    return AdminOverview(
      todayNewUsers: requireInt('todayNewUsers'),
      todayPosts: requireInt('todayPosts'),
      todayComments: requireInt('todayComments'),
      todayReports: requireInt('todayReports'),
      pendingReviews: requireInt('pendingReviews'),
      pendingCancellationRequests: requireInt('pendingCancellationRequests'),
      pendingFeedbacks: requireInt('pendingFeedbacks'),
      activeUsers: requireInt('activeUsers'),
      bannedUsers: requireInt('bannedUsers'),
      mutedUsers: requireInt('mutedUsers'),
    );
  }
}
