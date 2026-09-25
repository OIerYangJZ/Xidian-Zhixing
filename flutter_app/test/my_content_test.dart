import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/me/my_comments_page.dart';
import 'package:xdu_treehole_web/features/me/my_posts_page.dart';
import 'package:xdu_treehole_web/features/me/my_reports_page.dart';
import 'package:xdu_treehole_web/features/post/post_detail_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/report_item.dart';

/// AppRepositories keeps the first client it is given, so every test goes
/// through this one and swaps [_handler].
late Future<http.Response> Function(http.Request) _handler;
final http.Client _client = MockClient((http.Request r) => _handler(r));
final List<String> _calls = <String>[];

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(<String, Object>{'data': body}),
  status,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

Map<String, Object> _post(String id, {String status = 'ongoing'}) =>
    <String, Object>{
      'id': id,
      'title': '示例：帖子 $id',
      'content': '正文',
      'channel': '学习交流',
      'authorAlias': '我',
      'createdAt': DateTime.now().toIso8601String(),
      'status': status,
      'isOwnPost': true,
    };

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
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
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_calls.clear);

  testWidgets('a post status is set directly from its menu', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      _calls.add('${request.method} $path ${request.body}');
      if (path == '/posts/mine') {
        return _json(<Object>[_post('p1')]);
      }
      return _json(<String, Object>{});
    };
    await http.runWithClient(() async {
      await _pump(tester, const MyPostsPage());
      await tester.tap(find.byKey(const Key('my-post-status-p1')));
      await tester.pumpAndSettle();
      // 进行中 → 已结束 in one step; the old button went via 已解决.
      await tester.tap(find.text('已结束').last);
      await tester.pumpAndSettle();
      final String patch = _calls.firstWhere(
        (String c) => c.startsWith('PATCH'),
      );
      expect(patch, contains('/posts/p1'));
      expect(patch, contains('closed'));
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('a comment opens its post, and deleting asks first', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      _calls.add('${request.method} $path');
      if (path == '/comments/mine') {
        return _json(<Object>[
          <String, Object>{
            'id': 'c1',
            'postId': 'p9',
            'postTitle': '示例：原帖标题',
            'content': '我的评论内容',
            'timeText': '1 小时前',
          },
        ]);
      }
      if (path == '/posts/p9') return _json(_post('p9'));
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, const MyCommentsPage());
      await tester.tap(find.byKey(const Key('my-comment-delete-c1')));
      await tester.pumpAndSettle();
      expect(find.text('删除这条评论？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(_calls.where((String c) => c.startsWith('DELETE')), isEmpty);

      await tester.tap(find.text('我的评论内容'));
      await tester.pumpAndSettle();
      expect(_calls, contains('GET /posts/p9'));
      expect(find.byType(PostDetailPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  test('report labels read as words, not server values', () {
    final ReportItem item = ReportItem.fromJson(<String, dynamic>{
      'id': 'r1',
      'targetType': 'post',
      'targetId': 'abc',
      'targetTitle': '示例标题',
      'status': 'misreport',
    });
    const Locale zh = Locale('zh', 'CN');
    expect(item.statusLabelFor(zh), '举报未成立');
    expect(item.targetLabelFor(zh), '帖子「示例标题」');
    expect(
      ReportItem.fromJson(<String, dynamic>{
        'targetType': 'comment',
        'status': 'pending',
      }).targetLabelFor(zh),
      '评论',
    );
  });

  testWidgets('my reports show labels instead of raw values', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async => _json(<Object>[
      <String, Object>{
        'id': 'r1',
        'target': 'post: abc',
        'targetType': 'post',
        'targetId': 'abc',
        'targetTitle': '示例标题',
        'reason': '广告',
        'status': 'pending',
      },
    ]);
    await http.runWithClient(() async {
      await _pump(tester, const MyReportsPage());
      expect(find.text('帖子「示例标题」 · 广告'), findsOneWidget);
      expect(find.text('待处理'), findsOneWidget);
      expect(find.textContaining('post: abc'), findsNothing);
      expect(find.text('pending'), findsNothing);
    }, () => _client);
  });
}
