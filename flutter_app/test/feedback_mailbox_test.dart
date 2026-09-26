import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/me/feedback_mailbox_page.dart';
import 'package:xdu_treehole_web/features/notifications/notification_center_page.dart'
    as web;
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/mobile/features/notifications/notification_center_page.dart'
    as mobile;
import 'package:xdu_treehole_web/models/feedback_item.dart';
import 'package:xdu_treehole_web/models/notification_item.dart';
import 'package:xdu_treehole_web/repositories/notification_repository.dart';

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

/// What `_user_handler.handle_my_feedbacks` sends.
Map<String, Object> _record(
  String id, {
  String status = 'pending',
  String reply = '',
}) => <String, Object>{
  'id': id,
  'category': '平台功能建议',
  'content': '希望增加夜间模式',
  'contact': '',
  'status': status,
  'schoolReply': reply,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'handledAt': '',
};

final NotificationItem _feedbackNotice =
    NotificationItem.fromJson(<String, dynamic>{
      'id': 'n1',
      'type': 'system',
      'title': '信箱回复',
      'content': '已经在排期了',
      'relatedType': 'feedback',
      'relatedId': 'fb1',
      'isRead': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

class _FakeNotifications extends NotificationRepository {
  _FakeNotifications() : super(ApiClient());

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      <NotificationItem>[_feedbackNotice];

  @override
  Future<NotificationItem> markRead(String notificationId) async =>
      _feedbackNotice.copyWith(isRead: true);
}

const List<LocalizationsDelegate<dynamic>> _delegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

ThemeData get _theme => AppTheme.designSystemFor(
  themeKey: 'zhushachi',
  brightness: Brightness.light,
);

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1600);
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  _size(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(_FakeNotifications()),
      ],
      child: MaterialApp(
        theme: _theme,
        localizationsDelegates: _delegates,
        supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
        locale: const Locale('zh', 'CN'),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_calls.clear);

  test('a record must carry every field the server sends', () {
    expect(FeedbackItem.fromJson(_record('fb1')).isPending, isTrue);
    expect(
      () => FeedbackItem.fromJson(
        Map<String, dynamic>.from(_record('fb1'))..remove('schoolReply'),
      ),
      throwsFormatException,
    );
    expect(
      () => FeedbackItem.fromJson(_record('fb1', status: 'done')),
      throwsFormatException,
    );
  });

  testWidgets('the mailbox sends the chosen category and shows the reply', (
    WidgetTester tester,
  ) async {
    final List<Map<String, Object>> records = <Map<String, Object>>[
      _record('fb0', status: 'resolved', reply: '已经修好了'),
    ];
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      _calls.add('${request.method} $path ${request.body}');
      if (request.method == 'POST' && path == '/feedback') {
        records.insert(0, _record('fb1'));
        return _json(<String, Object>{'ok': true, 'id': 'fb1'});
      }
      if (path == '/feedback/mine') return _json(records);
      return _json(<String, Object>{});
    };
    await http.runWithClient(() async {
      await _pump(tester, const FeedbackMailboxPage());
      expect(find.text('已经修好了'), findsOneWidget);
      expect(find.text('已回复'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feedback-category-平台功能建议')));
      await tester.enterText(
        find.byKey(const Key('feedback-content')),
        '希望增加夜间模式',
      );
      await tester.enterText(
        find.byKey(const Key('feedback-contact')),
        'me@example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('feedback-submit')));
      await tester.pumpAndSettle();

      final String post = _calls.firstWhere(
        (String c) => c.startsWith('POST /feedback'),
      );
      final Map<String, dynamic> body =
          jsonDecode(post.substring(post.indexOf('{'))) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'category': '平台功能建议',
        'content': '希望增加夜间模式',
        'contact': 'me@example.com',
      });
      expect(find.byKey(const Key('feedback-record-fb1')), findsOneWidget);
      expect(find.text('待处理'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('web: a 信箱 reply notice opens the mailbox', (
    WidgetTester tester,
  ) async {
    _handler = (http.Request request) async =>
        _json(<Object>[_record('fb1', status: 'resolved', reply: '已经在排期了')]);
    await http.runWithClient(() async {
      await _pump(tester, const web.NotificationCenterPage());
      await tester.tap(find.textContaining('已经在排期了').first);
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackMailboxPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('Android: a 信箱 reply notice opens /profile/feedback', (
    WidgetTester tester,
  ) async {
    _size(tester);
    final GoRouter router = GoRouter(
      initialLocation: '/notifications',
      routes: <RouteBase>[
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const mobile.NotificationCenterPage(),
        ),
        GoRoute(
          path: '/profile/feedback',
          builder: (_, _) => const Scaffold(body: Text('mailbox-route')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotifications(),
          ),
        ],
        child: MaterialApp.router(
          theme: _theme,
          localizationsDelegates: _delegates,
          supportedLocales: const <Locale>[Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('已经在排期了').first);
    await tester.pumpAndSettle();
    expect(find.text('mailbox-route'), findsOneWidget);
  });
}
