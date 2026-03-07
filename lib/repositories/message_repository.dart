import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../data/mock_data.dart';
import '../models/conversation_item.dart';
import '../models/dm_request_item.dart';

class MessageRepository {
  MessageRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DmRequestItem>> fetchDmRequests() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.dmRequests);
      final List<dynamic> list = extractList(response);
      final List<DmRequestItem> items = list
          .map((dynamic item) => DmRequestItem.fromJson(asMap(item)))
          .where((DmRequestItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    if (AppConfig.enableMockFallback) {
      return mockDmRequests
          .asMap()
          .entries
          .map(
            (MapEntry<int, Map<String, String>> entry) => DmRequestItem(
              id: 'mock-${entry.key + 1}',
              fromAlias: entry.value['from'] ?? '匿名同学',
              fromAvatarUrl: entry.value['avatarUrl'] ?? '',
              reason: entry.value['reason'] ?? '请求联系',
              timeText: entry.value['time'] ?? '-',
              status: 'pending',
              statusLabel: '待处理',
            ),
          )
          .toList();
    }

    return <DmRequestItem>[];
  }

  Future<void> handleDmRequest({
    required String requestId,
    required bool accept,
  }) async {
    final String action = accept ? 'accept' : 'reject';
    await _apiClient.post(
      ApiEndpoints.dmRequestAction(requestId, action),
      body: const <String, dynamic>{},
    );
  }

  Future<List<ConversationItem>> fetchConversations() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.conversations);
      final List<dynamic> list = extractList(response);
      final List<ConversationItem> items = list
          .map((dynamic item) => ConversationItem.fromJson(asMap(item)))
          .where((ConversationItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    if (AppConfig.enableMockFallback) {
      return mockConversations
          .asMap()
          .entries
          .map(
            (MapEntry<int, Map<String, String>> entry) => ConversationItem(
              id: 'conv-mock-${entry.key + 1}',
              name: entry.value['name'] ?? '匿名同学',
              avatarUrl: entry.value['avatarUrl'] ?? '',
              lastMessage: entry.value['lastMessage'] ?? '-',
              timeText: entry.value['time'] ?? '-',
            ),
          )
          .toList();
    }

    return <ConversationItem>[];
  }
}
