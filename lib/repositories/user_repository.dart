import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../data/mock_data.dart';
import '../models/my_comment_item.dart';
import '../models/post_item.dart';
import '../models/report_item.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchProfile() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.me);
      final Map<String, dynamic> map = extractMap(response);
      if (map.isNotEmpty) {
        return UserProfile.fromJson(map);
      }
    } catch (_) {
      // ignore and fallback
    }

    final int fallbackFavorite =
        mockPosts.where((PostItem p) => p.favoriteCount > 15).length;
    return UserProfile(
      nickname: '洞主-雾蓝',
      studentId: '2023000001',
      avatarUrl: '',
      email: 'demo@stu.xidian.edu.cn',
      verified: true,
      verifiedAt: '2026-03-06',
      allowStrangerDm: true,
      showContactable: true,
      favoriteCount: fallbackFavorite,
      isAdmin: false,
      accountCancellationRequest: null,
    );
  }

  Future<void> updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) {
    return _apiClient.patch(
      ApiEndpoints.privacy,
      body: <String, dynamic>{
        'allowStrangerDm': allowStrangerDm,
        'showContactable': showContactable,
      },
    );
  }

  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
  }) {
    return _apiClient.patch(
      ApiEndpoints.me,
      body: <String, dynamic>{
        'nickname': nickname,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
  }

  Future<String> uploadAvatar({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.avatarUpload,
      body: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    return (map['avatarUrl'] ?? '').toString();
  }

  Future<List<MyCommentItem>> fetchMyComments() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myComments);
      final List<dynamic> list = extractList(response);
      final List<MyCommentItem> items = list
          .map((dynamic item) => MyCommentItem.fromJson(asMap(item)))
          .where((MyCommentItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty || !AppConfig.enableMockFallback) {
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    return mockMyComments
        .asMap()
        .entries
        .map(
          (MapEntry<int, Map<String, String>> entry) => MyCommentItem(
            id: 'mock-comment-${entry.key + 1}',
            postTitle: entry.value['post'] ?? '原帖',
            content: entry.value['content'] ?? '-',
            timeText: entry.value['time'] ?? '-',
          ),
        )
        .toList();
  }

  Future<void> deleteMyComment(String commentId) {
    return _apiClient.delete(ApiEndpoints.commentById(commentId));
  }

  Future<List<ReportItem>> fetchMyReports() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myReports);
      final List<dynamic> list = extractList(response);
      final List<ReportItem> items = list
          .map((dynamic item) => ReportItem.fromJson(asMap(item)))
          .where((ReportItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty || !AppConfig.enableMockFallback) {
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    return mockMyReports
        .asMap()
        .entries
        .map(
          (MapEntry<int, Map<String, String>> entry) => ReportItem(
            id: 'mock-report-${entry.key + 1}',
            target: entry.value['target'] ?? '-',
            targetType: '',
            targetId: '',
            targetTitle: '',
            reason: entry.value['reason'] ?? '-',
            description: '',
            status: entry.value['status'] ?? '-',
            result: '',
            createdAt: '',
            handledAt: '',
          ),
        )
        .toList();
  }

  Future<ReportItem> fetchMyReportDetail(String reportId) async {
    try {
      final dynamic response =
          await _apiClient.get(ApiEndpoints.reportById(reportId));
      final Map<String, dynamic> map = extractMap(response);
      if (map.isNotEmpty) {
        return ReportItem.fromJson(map);
      }
    } catch (_) {
      // ignore and fallback
    }

    final List<ReportItem> rows = await fetchMyReports();
    return rows.firstWhere(
      (ReportItem item) => item.id == reportId,
      orElse: () => ReportItem(
        id: reportId,
        target: '-',
        targetType: '',
        targetId: '',
        targetTitle: '',
        reason: '-',
        description: '',
        status: '-',
        result: '',
        createdAt: '',
        handledAt: '',
      ),
    );
  }

  Future<void> submitAccountCancellationRequest({String? reason}) {
    return _apiClient.post(
      ApiEndpoints.meCancellationRequest,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }
}
