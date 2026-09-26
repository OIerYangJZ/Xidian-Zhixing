import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/conversation_item.dart';
import '../models/direct_message_item.dart';
import '../core/l10n/ui_text.dart';

class MessageRepository {
  MessageRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ConversationItem>> fetchConversations() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.conversations);
    final List<dynamic> list = extractList(response);
    final List<ConversationItem> items = list
        .map((dynamic item) => ConversationItem.fromJson(asMap(item)))
        .toList();
    if (items.any((ConversationItem item) => item.id.isEmpty)) {
      throw FormatException(
        uiTextGlobal(
          zh: '会话列表包含无效记录',
          en: 'The conversation list contains invalid records',
        ),
      );
    }
    return items;
  }

  Future<List<DirectMessageItem>> fetchConversationMessages(
    String conversationId,
  ) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.dmConversationMessages(conversationId),
    );
    final List<dynamic> list = extractList(response);
    final List<DirectMessageItem> items = list
        .map((dynamic item) => DirectMessageItem.fromJson(asMap(item)))
        .toList();
    if (items.any((DirectMessageItem item) => item.id.isEmpty)) {
      throw FormatException(
        uiTextGlobal(
          zh: '消息列表包含无效记录',
          en: 'The message list contains invalid records',
        ),
      );
    }
    return items;
  }

  Future<DirectMessageItem> sendConversationMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.dmConversationMessages(conversationId),
      body: <String, dynamic>{
        'content': content,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    final DirectMessageItem item = DirectMessageItem.fromJson(map);
    if (item.id.isEmpty) {
      throw FormatException(
        uiTextGlobal(
          zh: '发送消息响应缺少消息数据',
          en: 'The send-message response is missing message data',
        ),
      );
    }
    return item;
  }

  Future<void> deleteConversation(String conversationId) {
    return _apiClient.delete(ApiEndpoints.dmConversation(conversationId));
  }

  /// Returns whether I now block the peer. The response is only
  /// `{"blocked": bool}`; whether the peer blocks me is unchanged.
  Future<bool> updateConversationBlock({
    required String conversationId,
    required bool block,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.dmConversationBlock(conversationId, block),
      body: const <String, dynamic>{},
    );
    final bool? blocked = readBool(extractMap(response), <String>['blocked']);
    if (blocked == null) {
      throw FormatException(
        uiTextGlobal(
          zh: '屏蔽操作响应缺少 blocked 状态',
          en: 'The block response is missing the blocked flag',
        ),
      );
    }
    return blocked;
  }

  Future<ConversationItem> createDirectConversation(
    String targetUserId, {
    String? fromPostId,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.directConversation,
      body: <String, dynamic>{
        'targetUserId': targetUserId.trim(),
        if (fromPostId != null && fromPostId.trim().isNotEmpty)
          'fromPostId': fromPostId.trim(),
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    return ConversationItem.fromJson(data);
  }

  Future<void> recallMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _apiClient.delete(
      ApiEndpoints.dmMessageRecall(messageId),
      queryParameters: {'conversationId': conversationId},
    );
  }
}
