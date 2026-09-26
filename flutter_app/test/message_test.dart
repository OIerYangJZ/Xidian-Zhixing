import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';
import 'package:xdu_treehole_web/models/direct_message_item.dart';
import 'package:xdu_treehole_web/repositories/message_repository.dart';
import 'api_mocks.dart';

void main() {
  group('MessageRepository', () {
    late MockClient mockClient;
    late MessageRepository messageRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        // 获取会话列表
        if (path.endsWith('/messages/conversations') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.conversationsSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 获取会话消息
        final messagesPattern = RegExp(r'/messages/conversations/.+/messages');
        if (messagesPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.messagesSuccess()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 发送消息
        if (messagesPattern.hasMatch(path) && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'new_msg_${DateTime.now().millisecondsSinceEpoch}',
              'content': body['content'] ?? '',
              'createdAt': DateTime.now().toIso8601String(),
              'timeText': '刚刚',
              'fromMe': true,
              'senderAlias': '我',
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 删除会话
        final deleteConversationPattern = RegExp(
          r'/messages/conversations/[^/]+$',
        );
        if (deleteConversationPattern.hasMatch(path) && method == 'DELETE') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '会话已删除'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 拉黑/取消拉黑
        final blockPattern = RegExp(r'/messages/conversations/.+/block');
        final unblockPattern = RegExp(r'/messages/conversations/.+/unblock');
        if ((blockPattern.hasMatch(path) || unblockPattern.hasMatch(path)) &&
            method == 'POST') {
          return http.Response(
            // What _message_handler.handle_block_peer / unblock send.
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{'blocked': !path.endsWith('/unblock')},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        return http.Response(
          jsonEncode(MockApiResponses.notFound()),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      messageRepository = MessageRepository(ApiClient(httpClient: mockClient));
    });

    group('fetchConversations', () {
      test('获取会话列表成功', () async {
        final conversations = await messageRepository.fetchConversations();

        expect(conversations, isNotEmpty);
        expect(conversations.first, isA<ConversationItem>());
        expect(conversations.first.name, equals('同学-海盐'));
      });

      test('返回的会话包含必要字段', () async {
        final conversations = await messageRepository.fetchConversations();
        final first = conversations.first;

        expect(first.id, isNotEmpty);
        expect(first.name, isNotEmpty);
        expect(first.lastMessage, isNotEmpty);
      });
    });

    group('fetchConversationMessages', () {
      test('获取会话消息列表成功', () async {
        final messages = await messageRepository.fetchConversationMessages(
          'conv1',
        );

        expect(messages, isNotEmpty);
        expect(messages.first, isA<DirectMessageItem>());
        expect(messages.first.content, isNotEmpty);
      });
    });

    group('sendConversationMessage', () {
      test('发送消息成功返回消息对象', () async {
        final message = await messageRepository.sendConversationMessage(
          conversationId: 'conv1',
          content: '你好，这是测试消息',
        );

        expect(message, isA<DirectMessageItem>());
        expect(message.content, equals('你好，这是测试消息'));
      });
    });

    group('deleteConversation', () {
      test('删除会话成功', () async {
        await expectLater(
          messageRepository.deleteConversation('conv1'),
          completes,
        );
      });
    });

    group('updateConversationBlock', () {
      test('拉黑会话成功', () async {
        final result = await messageRepository.updateConversationBlock(
          conversationId: 'conv1',
          block: true,
        );

        expect(result, isTrue);
      });

      test('取消拉黑成功', () async {
        final result = await messageRepository.updateConversationBlock(
          conversationId: 'conv1',
          block: false,
        );

        expect(result, isFalse);
      });
    });

    group('ConversationItem', () {
      test('fromJson 读取 awaitingReply', () {
        final item = ConversationItem.fromJson(<String, dynamic>{
          'id': 'c1',
          'awaitingReply': true,
        });
        expect(item.awaitingReply, isTrue);
        expect(
          ConversationItem.fromJson(<String, dynamic>{}).awaitingReply,
          isFalse,
        );
      });

      test('fromJson 正确解析', () {
        final json = <String, dynamic>{
          'id': 'conv123',
          'peerUserId': 'user456',
          'name': '同学-对话',
          'avatarUrl': '',
          'lastMessage': '最后一条消息',
          'timeText': '14:30',
        };

        final item = ConversationItem.fromJson(json);

        expect(item.id, equals('conv123'));
        expect(item.peerUserId, equals('user456'));
        expect(item.name, equals('同学-对话'));
        expect(item.lastMessage, equals('最后一条消息'));
        expect(item.timeText, equals('14:30'));
      });

      test('fromJson 处理空数据', () {
        final item = ConversationItem.fromJson(<String, dynamic>{});

        expect(item.id, isEmpty);
        expect(item.name, equals('匿名同学'));
      });

      test('isBlocked 属性正确计算', () {
        final blocked = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv1',
          'blockedByMe': true,
        });
        expect(blocked.isBlocked, isTrue);

        final notBlocked = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv2',
          'blockedByMe': false,
          'blockedByPeer': false,
        });
        expect(notBlocked.isBlocked, isFalse);
      });

      test('copyWith 创建新实例', () {
        final original = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv1',
          'name': '原名称',
          'lastMessage': '原消息',
        });

        final modified = original.copyWith(name: '新名称');

        expect(modified.id, equals('conv1'));
        expect(modified.name, equals('新名称'));
        expect(modified.lastMessage, equals('原消息'));
      });
    });

    group('DirectMessageItem', () {
      test('fromJson 读取撤回占位，撤回的消息不能再撤回', () {
        final item = DirectMessageItem.fromJson(<String, dynamic>{
          'id': 'm1',
          'content': '',
          'recalled': true,
          'deliveryStatus': 'recalled',
          'fromMe': true,
          'canRecall': false,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        expect(item.recalled, isTrue);
        expect(item.canRecall, isFalse);
      });

      test('fromJson 正确解析', () {
        final json = <String, dynamic>{
          'id': 'msg123',
          'content': '消息内容',
          'createdAt': '2024-01-15T10:30:00Z',
          'timeText': '10:30',
          'fromMe': true,
          'senderAlias': '我',
        };

        final item = DirectMessageItem.fromJson(json);

        expect(item.id, equals('msg123'));
        expect(item.content, equals('消息内容'));
        expect(item.createdAt, equals('2024-01-15T10:30:00Z'));
        expect(item.fromMe, isTrue);
        expect(item.senderAlias, equals('我'));
      });

      test('fromJson 处理空数据', () {
        final item = DirectMessageItem.fromJson(<String, dynamic>{});

        expect(item.id, isEmpty);
        expect(item.content, isEmpty);
        expect(item.fromMe, isFalse);
        expect(item.senderAlias, equals('匿名同学'));
      });

      test('isRead 根据 readAt 判断', () {
        final readMessage = DirectMessageItem.fromJson(<String, dynamic>{
          'id': 'msg1',
          'content': '已读消息',
          'readAt': '2024-01-15T10:35:00Z',
        });
        expect(readMessage.isRead, isTrue);

        final unreadMessage = DirectMessageItem.fromJson(<String, dynamic>{
          'id': 'msg2',
          'content': '未读消息',
        });
        expect(unreadMessage.isRead, isFalse);
      });
    });
  });
}
