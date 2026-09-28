import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/admin/admin_console_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/repositories/admin_repository.dart';

final List<http.Request> _posts = <http.Request>[];

AdminRepository _repo({bool primary = true}) => AdminRepository(
  ApiClient(
    httpClient: MockClient((http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      if (request.method == 'POST') _posts.add(request);
      // Like the backend: everything but pin requests is primary-only.
      if (!primary &&
          path != '/admin/auth/me' &&
          path != '/admin/post-pin-requests') {
        return http.Response(
          jsonEncode(<String, Object>{'message': '需要一级管理员权限'}),
          403,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      final Object body = switch (path) {
        '/admin/auth/me' => <String, Object>{
          'username': 'admin',
          'roleLabel': primary ? '一级管理员' : '二级管理员',
          'isPrimary': primary,
        },
        '/admin/reports' => <Object>[
          <String, Object>{
            'id': 'r1',
            'targetType': 'post',
            'targetId': 'p1',
            'reason': '广告',
            'status': 'pending',
          },
          <String, Object>{
            'id': 'r2',
            'targetType': 'post',
            'targetId': 'p2',
            'reason': '广告',
            'status': 'resolved',
            'result': '已删除内容',
          },
        ],
        '/admin/feedbacks' => <Object>[
          <String, Object>{
            'id': 'fb1',
            'userNickname': '小西',
            'userEmail': '2500400@stu.xidian.edu.cn',
            'category': '校园建议',
            'content': '食堂太挤',
            'contact': '',
            'status': 'pending',
            'schoolReply': '',
            'createdAt': '2026-09-26T00:00:00+00:00',
            'handledAt': '',
          },
        ],
        '/admin/feedbacks/fb1/handle' => <String, Object>{'id': 'fb1'},
        '/admin/overview' => <String, Object>{
          'todayNewUsers': 0,
          'todayPosts': 0,
          'todayComments': 0,
          'todayReports': 0,
          'pendingReviews': 0,
          'pendingCancellationRequests': 0,
          'pendingFeedbacks': 0,
          'activeUsers': 0,
          'bannedUsers': 0,
          'mutedUsers': 0,
        },
        '/admin/tags' => <String, Object>{'tags': <String>['食堂']},
        '/admin/config' => <String, Object>{
          'sensitiveWords': <String>[],
          'settings': <String, int>{
            'postRateLimit': 5,
            'commentRateLimit': 20,
            'messageRateLimit': 30,
            'imageMaxMB': 5,
          },
        },
        _ => <String, Object>{},
      };
      return http.Response(
        jsonEncode(<String, Object>{'data': body}),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }),
  ),
);

Widget _console(AdminRepository repository) => MaterialApp(
  theme: AppTheme.designSystemFor(
    themeKey: 'zhuqing',
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
  home: AdminConsolePage(repository: repository),
);

void main() {
  testWidgets('a secondary admin gets the pin requests, not a 403 page', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_console(_repo(primary: false)));
    await tester.pumpAndSettle();
    expect(find.text('需要一级管理员权限'), findsNothing);
    expect(find.byKey(const Key('admin-section-帖子置顶')), findsOneWidget);
    expect(find.byKey(const Key('admin-section-用户管理')), findsNothing);
    expect(find.byKey(const Key('admin-section-举报处理')), findsNothing);
  });

  testWidgets('only pending reports offer actions; the sidebar counts them', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_console(_repo()));
    await tester.pumpAndSettle();

    final Finder reportsEntry = find.byKey(const Key('admin-section-举报处理'));
    expect(
      find.descendant(of: reportsEntry, matching: find.text('1')),
      findsOneWidget,
      reason: 'one pending report',
    );
    await tester.tap(reportsEntry);
    await tester.pumpAndSettle();
    // r1 has the four actions; r2, already handled, has none.
    expect(find.text('标记误报'), findsOneWidget);
    expect(find.text('封禁用户'), findsOneWidget);
    expect(find.text('处理结果：已删除内容'), findsOneWidget);
  });

  testWidgets('a pending feedback can be answered from 用户反馈', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.reset);
    _posts.clear();
    await tester.pumpWidget(_console(_repo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-section-用户反馈')));
    await tester.pumpAndSettle();
    expect(find.text('食堂太挤'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-feedback-reply-fb1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-note-input')), '已错峰开放');
    await tester.tap(find.byKey(const Key('admin-note-confirm')));
    await tester.pumpAndSettle();

    final http.Request sent = _posts.single;
    expect(sent.url.path, '/api/admin/feedbacks/fb1/handle');
    expect(jsonDecode(sent.body), <String, Object>{
      'action': 'reply',
      'reply': '已错峰开放',
    });
  });
}
