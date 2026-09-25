import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/messages/chat_page.dart';
import 'package:xdu_treehole_web/features/messages/messages_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';

ConversationItem _conversation({
  bool blockedByMe = false,
  bool awaitingReply = false,
}) => ConversationItem(
  id: 'c1',
  peerUserId: 'u1',
  name: '同学甲',
  avatarUrl: '',
  lastMessage: '在吗',
  timeText: '10:00',
  blockedByMe: blockedByMe,
  awaitingReply: awaitingReply,
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.designSystemFor(
          themeKey: 'zhushachi',
          brightness: Brightness.light,
        ),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
        locale: const Locale('zh', 'CN'),
        home: home,
      ),
    ),
  );
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

/// AppRepositories keeps the first client it is given, so every test goes
/// through this one and swaps [_handler].
late Future<http.Response> Function(http.Request) _handler;
final http.Client _client = MockClient((http.Request r) => _handler(r));

void main() {
  testWidgets('the list has no message requests', (WidgetTester tester) async {
    final List<String> asked = <String>[];
    _handler = (http.Request request) async {
      asked.add(request.url.path.replaceFirst('/api', ''));
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, const MessagesPage());
      // No request step: a first message goes straight into a chat.
      expect(asked, isNot(contains('/messages/requests')));
      expect(find.byKey(const Key('dm-requests-card')), findsNothing);
      expect(find.textContaining('私信请求'), findsNothing);
    }, () => _client);
  });

  testWidgets('a failed send leaves a bubble that resends', (
    WidgetTester tester,
  ) async {
    int sends = 0;
    _handler = (http.Request request) async {
      if (request.method == 'POST') {
        sends++;
        if (sends == 1) return _json(<String, Object>{'error': 'x'}, 500);
        return _json(<String, Object>{
          'id': 'm9',
          'content': '你好',
          'fromMe': true,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, ChatPage(conversation: _conversation()));
      expect(find.byKey(const Key('chat-view-profile')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat-input')), '你好');
      await tester.tap(find.byKey(const Key('chat-send')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('chat-failed-message')), findsOneWidget);
      expect(find.text('发送失败 · 重发'), findsOneWidget);

      await tester.tap(find.text('发送失败 · 重发'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(sends, 2);
      expect(find.byKey(const Key('chat-failed-message')), findsNothing);
      expect(find.text('你好'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('blocking replaces the input with 解除屏蔽', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async {
      if (request.url.path.endsWith('/unblock')) {
        return _json(<String, Object>{
          'id': 'c1',
          'blockedByMe': false,
          'blockedByPeer': false,
        });
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(
        tester,
        ChatPage(conversation: _conversation(blockedByMe: true)),
      );
      expect(find.byKey(const Key('chat-blocked-panel')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);

      await tester.tap(find.byKey(const Key('chat-unblock')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('chat-blocked-panel')), findsNothing);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('before a reply, one first message locks the input', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async {
      if (request.method == 'POST') {
        return _json(<String, Object>{
          'id': 'm1',
          'content': '你好，想组队',
          'fromMe': true,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, ChatPage(conversation: _conversation()));
      expect(find.byKey(const Key('chat-first-message-note')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat-input')), '你好，想组队');
      await tester.tap(find.byKey(const Key('chat-send')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('消息已发送'), findsOneWidget);
      expect(find.byKey(const Key('chat-waiting-panel')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);
    }, () => _client);
  });

  testWidgets('the server holding a second message locks the input', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async {
      if (request.method == 'POST') {
        return _json(<String, Object>{'message': '对方回复前只能发送一条消息'}, 403);
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, ChatPage(conversation: _conversation()));
      await tester.enterText(find.byKey(const Key('chat-input')), '在吗');
      await tester.tap(find.byKey(const Key('chat-send')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('chat-waiting-panel')), findsOneWidget);
      expect(find.byKey(const Key('chat-failed-message')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('a conversation still awaiting a reply opens locked', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async => _json(<Object>[
      <String, Object>{
        'id': 'm1',
        'content': '你好',
        'fromMe': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ]);
    await http.runWithClient(() async {
      await _pump(
        tester,
        ChatPage(conversation: _conversation(awaitingReply: true)),
      );
      expect(find.byKey(const Key('chat-waiting-panel')), findsOneWidget);
      expect(find.text('暂时不能发送'), findsOneWidget);
    }, () => _client);
  });
}
