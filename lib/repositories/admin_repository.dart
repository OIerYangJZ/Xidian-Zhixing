import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminOverview> fetchOverview() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminOverview);
    final Map<String, dynamic> data = extractMap(response);
    return AdminOverview.fromJson(data);
  }

  Future<List<AdminReviewItem>> fetchReviews({
    required String type,
    required String status,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminReviews,
      queryParameters: <String, dynamic>{
        'type': type,
        'status': status,
      },
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminReviewItem.fromJson(asMap(item)))
        .where((AdminReviewItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleReview({
    required String targetType,
    required String targetId,
    required String action,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminReviewAction(targetType, targetId, action),
      body: const <String, dynamic>{},
    );
  }

  Future<List<AdminReportEntry>> fetchReports({
    String status = 'all',
    String? reason,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminReports,
      queryParameters: <String, dynamic>{
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminReportEntry.fromJson(asMap(item)))
        .where((AdminReportEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<AdminImageReviewItem>> fetchImageReviews({
    String status = 'pending',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminImageReviews,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );

    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminImageReviewItem.fromJson(asMap(item)))
        .where((AdminImageReviewItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleReport({
    required String reportId,
    required String action,
    String? result,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminReportHandle(reportId),
      body: <String, dynamic>{
        'action': action,
        if (result != null && result.trim().isNotEmpty) 'result': result.trim(),
      },
    );
  }

  Future<List<AdminUserEntry>> fetchUsers() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminUsers);
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminUserEntry.fromJson(asMap(item)))
        .where((AdminUserEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> updateUserState({
    required String userId,
    required String action,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminUserAction(userId),
      body: <String, dynamic>{'action': action},
    );
  }

  Future<void> handleImageReview({
    required String uploadId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminImageReview(uploadId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<AdminChannelTagData> fetchChannelTagData() async {
    final dynamic response =
        await _apiClient.get(ApiEndpoints.adminChannelsTags);
    final Map<String, dynamic> data = extractMap(response);
    return AdminChannelTagData.fromJson(data);
  }

  Future<void> addChannel(String name) {
    return _apiClient.post(
      ApiEndpoints.adminChannels,
      body: <String, dynamic>{'name': name},
    );
  }

  Future<void> renameChannel({
    required String oldName,
    required String newName,
  }) {
    return _apiClient.patch(
      ApiEndpoints.adminChannelByName(_encodePath(oldName)),
      body: <String, dynamic>{'newName': newName},
    );
  }

  Future<void> deleteChannel(String name) {
    return _apiClient
        .delete(ApiEndpoints.adminChannelByName(_encodePath(name)));
  }

  Future<void> addTag(String name) {
    return _apiClient.post(
      ApiEndpoints.adminTags,
      body: <String, dynamic>{'name': name},
    );
  }

  Future<void> renameTag({
    required String oldName,
    required String newName,
  }) {
    return _apiClient.patch(
      ApiEndpoints.adminTagByName(_encodePath(oldName)),
      body: <String, dynamic>{'newName': newName},
    );
  }

  Future<void> deleteTag(String name) {
    return _apiClient.delete(ApiEndpoints.adminTagByName(_encodePath(name)));
  }

  Future<AdminSystemConfig> fetchConfig() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminConfig);
    final Map<String, dynamic> data = extractMap(response);
    return AdminSystemConfig.fromJson(data);
  }

  Future<void> updateConfig(AdminSystemConfig config) {
    return _apiClient.patch(
      ApiEndpoints.adminConfig,
      body: config.toRequestJson(),
    );
  }

  String _encodePath(String value) {
    return Uri.encodeComponent(value);
  }
}
