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

ConversationItem _conversation({bool blockedByMe = false}) => ConversationItem(
  id: 'c1',
  peerUserId: 'u1',
  name: '同学甲',
  avatarUrl: '',
  lastMessage: '在吗',
  timeText: '10:00',
  blockedByMe: blockedByMe,
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
  testWidgets('pending DM requests show on the list and can be accepted', (
    WidgetTester tester,
  ) async {
    final List<String> posts = <String>[];
    bool accepted = false;
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      if (request.method == 'POST') {
        posts.add(path);
        accepted = true;
        return _json(<String, Object>{});
      }
      if (path == '/messages/requests') {
        return _json(<Object>[
          <String, Object>{
            'id': 'r1',
            'fromAlias': '周同学',
            'reason': '想组队',
            'status': accepted ? 'accepted' : 'pending',
          },
          <String, Object>{
            'id': 'r0',
            'fromAlias': '旧请求',
            'status': 'rejected',
          },
        ]);
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, const MessagesPage());
      expect(find.byKey(const Key('dm-requests-card')), findsOneWidget);
      expect(find.text('私信请求 · 1 条待处理'), findsOneWidget);
      expect(find.text('旧请求'), findsNothing, reason: 'only pending ones');

      await tester.tap(find.text('同意'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(posts, <String>['/messages/requests/r1/accept']);
      expect(find.byKey(const Key('dm-requests-card')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
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
}
