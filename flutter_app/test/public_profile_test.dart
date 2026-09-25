import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/profile/public_user_profile_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';

/// AppRepositories keeps the first client it is given, so every test goes
/// through this one and swaps [_handler].
late Future<http.Response> Function(http.Request) _handler;
final http.Client _client = MockClient((http.Request r) => _handler(r));

http.Response _json(Object body) => http.Response(
  jsonEncode(<String, Object>{'data': body}),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1400);
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
        home: const PublicUserProfilePage(userId: 'u1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blocking from ⋯ hides the posts and leaves 解除屏蔽', (
    WidgetTester tester,
  ) async {
    bool blocked = false;
    final List<String> writes = <String>[];
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      if (request.method != 'GET') {
        writes.add('${request.method} $path ${request.body}');
        if (path == '/users/me/blocks') blocked = true;
        return _json(<String, Object>{});
      }
      if (path == '/users/u1') {
        return _json(<String, Object>{
          'id': 'u1',
          'nickname': '林小舟',
          'canFollow': true,
          'canDirectMessage': !blocked,
          'isFollowing': true,
          'isFollower': true,
          'isBlockedByMe': blocked,
        });
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester);
      expect(find.text('互相关注'), findsOneWidget);
      expect(find.byKey(const Key('public-profile-dm')), findsOneWidget);

      await tester.tap(find.byKey(const Key('public-profile-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽').last); // confirm
      await tester.pumpAndSettle();

      expect(writes.single, contains('POST /users/me/blocks'));
      expect(writes.single, contains('u1'));
      expect(find.byKey(const Key('public-profile-blocked')), findsOneWidget);
      expect(find.byKey(const Key('public-profile-unblock')), findsOneWidget);
      expect(find.byKey(const Key('public-profile-dm')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('reporting from ⋯ reports the user', (WidgetTester tester) async {
    final List<Map<String, dynamic>> reports = <Map<String, dynamic>>[];
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      if (request.method == 'POST' && path == '/reports') {
        reports.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(<String, Object>{'ok': true});
      }
      if (path == '/users/u1') {
        return _json(<String, Object>{
          'id': 'u1',
          'nickname': '林小舟',
          'canFollow': true,
        });
      }
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('public-profile-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('举报'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('人身攻击'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认举报'));
      await tester.pumpAndSettle();

      expect(reports.single['targetType'], 'user');
      expect(reports.single['targetId'], 'u1');
      expect(reports.single['reason'], '人身攻击');
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });
}
