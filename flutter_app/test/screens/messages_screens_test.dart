import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/features/messages/chat_page.dart';
import 'package:xdu_treehole_web/features/messages/messages_page.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  String ago(Duration d) => DateTime.now().subtract(d).toIso8601String();
  String hm(Duration d) {
    final DateTime at = DateTime.now().subtract(d);
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  Map<String, Object?> conversation(
    String id,
    String name,
    String last,
    String time, {
    int unread = 0,
    bool blockedByMe = false,
    bool blockedByPeer = false,
  }) => <String, Object?>{
    'id': id,
    'peerUserId': 'u-$id',
    'name': name,
    'lastMessage': last,
    'timeText': time,
    'unreadCount': unread,
    'blockedByMe': blockedByMe,
    'blockedByPeer': blockedByPeer,
  };

  final List<Map<String, Object?>> conversations = <Map<String, Object?>>[
    conversation('c1', '林小舟', '可以，周三晚上我都有空。', '09:55'),
    conversation('c2', '周同学', '示例：谢谢你的笔记！', '昨天', unread: 2),
    conversation('c3', '陈同学', '示例：好的，到时候见。', '09-20', unread: 1),
    conversation('c4', '王同学', '对方已屏蔽你，只能查看历史消息', '09-18', blockedByPeer: true),
    conversation('c5', '赵同学', '示例：收到。', '09-12', blockedByMe: true),
  ];

  final List<Map<String, Object?>> messages = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'm1',
      'content': '示例：你好，看到你在评论区留言，方便聊聊比赛安排吗？',
      'createdAt': ago(const Duration(minutes: 30)),
      'timeText': hm(const Duration(minutes: 30)),
      'senderAlias': '林小舟',
    },
    <String, Object?>{
      'id': 'm2',
      'content': '可以，周三晚上我都有空。',
      'createdAt': ago(const Duration(minutes: 27)),
      'timeText': hm(const Duration(minutes: 27)),
      'fromMe': true,
      'isRead': true,
      'replyToId': 'm1',
      'replyToSender': '林小舟',
      'replyToContent': '方便聊聊比赛安排吗？',
    },
    <String, Object?>{
      'id': 'm3',
      'content': '示例：好，那我先把题目 PDF 发你。',
      'createdAt': ago(const Duration(minutes: 5)),
      'timeText': hm(const Duration(minutes: 5)),
      'senderAlias': '林小舟',
    },
  ];

  /// Answers GETs from the fixtures; posting a message fails, for 发送失败.
  http.Client client() => MockClient((http.Request request) async {
    final String path = request.url.path.replaceFirst('/api', '');
    Object body = <String, Object>{};
    int status = 200;
    if (path == '/messages/conversations') {
      body = conversations;
    } else if (path.endsWith('/messages') && request.method == 'GET') {
      body = messages;
    } else if (path.endsWith('/messages')) {
      status = 500;
      body = <String, Object>{'error': '网络异常'};
    }
    return http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('messages desktop ${b.name}', (WidgetTester tester) async {
      await http.runWithClient(
        () => captureScreen(
          tester,
          name: 'messages_desktop_${b.name}',
          home: const MessagesPage(),
          size: desktop,
          brightness: b,
          beforeCapture: () async {
            await tester.tap(find.text('林小舟').first);
            for (int i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            // Leave a failed send and a pending reply on screen.
            await tester.enterText(
              find.byKey(const Key('chat-input')),
              '地点定在图书馆研讨间？',
            );
            await tester.tap(find.byKey(const Key('chat-send')));
            for (int i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          },
        ),
        client,
      );
    }, skip: !capturing);

    testWidgets('messages list phone ${b.name}', (WidgetTester tester) async {
      await http.runWithClient(
        () => captureScreen(
          tester,
          name: 'messages_list_phone_${b.name}',
          home: const MessagesPage(),
          size: phone,
          brightness: b,
        ),
        client,
      );
    }, skip: !capturing);

    testWidgets('chat phone ${b.name}', (WidgetTester tester) async {
      await http.runWithClient(
        () => captureScreen(
          tester,
          name: 'chat_phone_${b.name}',
          home: ChatPage(
            conversation: ConversationItem.fromJson(conversations.first),
          ),
          size: phone,
          brightness: b,
        ),
        client,
      );
    }, skip: !capturing);
  }

  testWidgets('chat blocked phone', (WidgetTester tester) async {
    await http.runWithClient(
      () => captureScreen(
        tester,
        name: 'chat_blocked_phone_light',
        home: ChatPage(
          conversation: ConversationItem.fromJson(conversations.last),
        ),
        size: phone,
      ),
      client,
    );
  }, skip: !capturing);
}
