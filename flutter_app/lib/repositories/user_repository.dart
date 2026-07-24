import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/follow_user_item.dart';
import '../models/my_comment_item.dart';
import '../models/report_item.dart';
import '../models/user_profile.dart';
import '../models/public_user_profile.dart';

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchProfile() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.me);
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return UserProfile.fromJson(map);
    }
    throw Exception('个人资料加载失败：服务端未返回有效数据');
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

  Future<void> updateNotificationPreferences({
    required bool notifyComment,
    required bool notifyReply,
    required bool notifyLike,
    required bool notifyFavorite,
    required bool notifyReportResult,
    required bool notifySystem,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      'notifyComment': notifyComment,
      'notifyReply': notifyReply,
      'notifyLike': notifyLike,
      'notifyFavorite': notifyFavorite,
      'notifyReportResult': notifyReportResult,
      'notifySystem': notifySystem,
    };

    return _apiClient.patch(ApiEndpoints.notificationPreferences, body: body);
  }

  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? bio,
    String? backgroundImageUrl,
    String? gender,
  }) {
    final body = <String, dynamic>{'nickname': nickname};

    if (avatarUrl != null) {
      body['avatarUrl'] = avatarUrl;
    }
    if (bio != null) {
      body['bio'] = bio;
    }
    if (backgroundImageUrl != null) {
      body['backgroundImageUrl'] = backgroundImageUrl;
    }
    if (gender != null) {
      body['gender'] = gender;
    }

    return _apiClient.patch(ApiEndpoints.me, body: body);
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
        'avatarContentType': contentType,
        'contentType': contentType,
        'avatarDataBase64': dataBase64,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    final String avatarUrl = (map['avatarUrl'] ?? '').toString().trim();
    if (avatarUrl.isEmpty) {
      throw const FormatException('头像上传响应缺少 avatarUrl');
    }
    return avatarUrl;
  }

  Future<String> uploadBackgroundImage({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.uploadImages,
      body: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    final String status = (map['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'approved') {
      final String moderationReason = (map['moderationReason'] ?? '')
          .toString()
          .trim();
      throw FormatException(
        moderationReason.isEmpty ? '背景图片尚未通过审核' : moderationReason,
      );
    }
    final String url = (map['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw const FormatException('背景图片上传响应缺少 url');
    }
    return url;
  }

  Future<List<MyCommentItem>> fetchMyComments() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myComments);
    final List<dynamic> list = extractList(response);
    final List<MyCommentItem> items = list
        .map((dynamic item) => MyCommentItem.fromJson(asMap(item)))
        .toList();
    if (items.any((MyCommentItem item) => item.id.isEmpty)) {
      throw const FormatException('我的评论列表包含无效记录');
    }
    return items;
  }

  Future<void> deleteMyComment(String commentId) {
    return _apiClient.delete(ApiEndpoints.commentById(commentId));
  }

  Future<List<ReportItem>> fetchMyReports() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myReports);
    final List<dynamic> list = extractList(response);
    final List<ReportItem> items = list
        .map((dynamic item) => ReportItem.fromJson(asMap(item)))
        .toList();
    if (items.any((ReportItem item) => item.id.isEmpty)) {
      throw const FormatException('举报列表包含无效记录');
    }
    return items;
  }

  Future<ReportItem> fetchMyReportDetail(String reportId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.reportById(reportId),
    );
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      throw const FormatException('举报详情响应缺少数据');
    }
    return ReportItem.fromJson(map);
  }

  Future<void> submitAccountCancellationRequest({String? reason}) {
    return _apiClient.post(
      ApiEndpoints.meCancellationRequest,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> submitLevelUpgradeRequest({String? reason}) {
    return _apiClient.post(
      ApiEndpoints.meLevelUpgradeRequest,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<List<FollowUserItem>> fetchFollowing() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myFollowing);
    final List<dynamic> list = extractList(response);
    final List<FollowUserItem> items = list
        .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
        .toList();
    if (items.any((FollowUserItem item) => item.userId.isEmpty)) {
      throw const FormatException('关注列表包含无效记录');
    }
    return items;
  }

  Future<List<FollowUserItem>> fetchFollowers() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myFollowers);
    final List<dynamic> list = extractList(response);
    final List<FollowUserItem> items = list
        .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
        .toList();
    if (items.any((FollowUserItem item) => item.userId.isEmpty)) {
      throw const FormatException('粉丝列表包含无效记录');
    }
    return items;
  }

  Future<List<FollowUserItem>> fetchFriends() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myFriends);
    final List<dynamic> list = extractList(response);
    final List<FollowUserItem> items = list
        .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
        .toList();
    if (items.any((FollowUserItem item) => item.userId.isEmpty)) {
      throw const FormatException('好友列表包含无效记录');
    }
    return items;
  }

  Future<List<PublicUserProfile>> searchUsers(String keyword) async {
    final String normalized = keyword.trim();
    if (normalized.isEmpty) {
      return <PublicUserProfile>[];
    }
    final dynamic response = await _apiClient.get(
      ApiEndpoints.userSearch,
      queryParameters: <String, dynamic>{'keyword': normalized},
    );
    final List<dynamic> list = extractList(response);
    final List<PublicUserProfile> items = list
        .map((dynamic item) => PublicUserProfile.fromJson(asMap(item)))
        .toList();
    if (items.any((PublicUserProfile item) => item.id.isEmpty)) {
      throw const FormatException('用户搜索结果包含无效记录');
    }
    return items;
  }

  Future<void> followUser(String userId) {
    return _apiClient.post(
      ApiEndpoints.followUser(userId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unfollowUser(String userId) {
    return _apiClient.post(
      ApiEndpoints.unfollowUser(userId),
      body: const <String, dynamic>{},
    );
  }

  Future<PublicUserProfile> fetchUserProfile(String userId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.userProfile(userId),
    );
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return PublicUserProfile.fromJson(map);
    }
    throw Exception('用户资料加载失败');
  }
}
