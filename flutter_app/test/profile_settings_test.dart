import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/state/app_theme_store.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/profile/notification_preferences_page.dart';
import 'package:xdu_treehole_web/features/profile/profile_page.dart';
import 'package:xdu_treehole_web/features/profile/settings_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';

Map<String, Object> _me({bool levelOne = false, Object? levelRequest}) =>
    <String, Object>{
      'id': 'me',
      'nickname': '示例昵称',
      'studentId': '21009200137',
      'postCount': 12,
      'followingCount': 36,
      'followerCount': 20,
      'userLevel': levelOne ? 1 : 2,
      'isLevelOneUser': levelOne,
      'notifyComment': true,
      'notifyReply': true,
      'notifyLike': true,
      'notifyFavorite': true,
      'notifyRepost': false,
      'notifyMention': true,
      'notifyReportResult': true,
      'notifySystem': true,
      'levelUpgradeRequest': ?levelRequest,
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(<String, Object>{'data': body}),
  status,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

/// AppRepositories keeps the first client it is given, so every test goes
/// through this one and swaps [_handler].
late Future<http.Response> Function(http.Request) _handler;
final http.Client _client = MockClient((http.Request r) => _handler(r));

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 2200);
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
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('profile shows counts and submits a level-upgrade request', (
    WidgetTester tester,
  ) async {
    final List<String> posts = <String>[];
    Object? levelRequest;
    _handler = (http.Request request) async {
      final String path = request.url.path.replaceFirst('/api', '');
      if (request.method == 'POST') {
        posts.add('$path ${request.body}');
        levelRequest = <String, Object>{'id': 'lr1', 'status': 'pending'};
        return _json(<String, Object>{});
      }
      if (path == '/users/me') return _json(_me(levelRequest: levelRequest));
      return _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, const ProfilePage());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.textContaining('21****0137'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile-level-upgrade')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('reason-dialog-input')),
        '社团负责人',
      );
      await tester.tap(find.byKey(const Key('reason-dialog-submit')));
      await _settle(tester);

      expect(posts, hasLength(1));
      expect(posts.single, startsWith('/users/me/level-upgrade-request'));
      expect(posts.single, contains('社团负责人'));
      expect(find.text('已提交申请，等待管理员审核'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('level 1 users get no upgrade row', (WidgetTester tester) async {
    _handler = (http.Request request) async =>
        request.url.path.endsWith('/users/me')
        ? _json(_me(levelOne: true))
        : _json(<Object>[]);
    await http.runWithClient(() async {
      await _pump(tester, const ProfilePage());
      expect(find.byKey(const Key('profile-level-upgrade')), findsNothing);
    }, () => _client);
  });

  testWidgets('a notification switch saves all eight and rolls back on failure', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> patches = <Map<String, dynamic>>[];
    bool fail = false;
    _handler = (http.Request request) async {
      if (request.method == 'PATCH') {
        patches.add(jsonDecode(request.body) as Map<String, dynamic>);
        return fail
            ? _json(<String, Object>{'error': 'x'}, 500)
            : _json(<String, Object>{});
      }
      return _json(_me());
    };
    await http.runWithClient(() async {
      await _pump(tester, const NotificationPreferencesPage());
      await tester.tap(find.byKey(const Key('notify-like')));
      await _settle(tester);
      expect(patches.single['notifyLike'], false);
      expect(patches.single.keys, hasLength(8));
      // The repost and mention switches are their own, loaded and sent.
      expect(patches.single['notifyRepost'], false);
      expect(
        tester.widget<Switch>(find.byKey(const Key('notify-repost'))).value,
        isFalse,
      );
      expect(
        tester.widget<Switch>(find.byKey(const Key('notify-like'))).value,
        isFalse,
      );

      await tester.ensureVisible(find.byKey(const Key('notify-mention')));
      await tester.tap(find.byKey(const Key('notify-mention')));
      await _settle(tester);
      expect(patches.last['notifyMention'], false);
      expect(patches.last['notifyLike'], false);

      fail = true;
      await tester.ensureVisible(find.byKey(const Key('notify-reply')));
      await tester.tap(find.byKey(const Key('notify-reply')));
      await _settle(tester);
      expect(patches.last['notifyReply'], false);
      expect(
        tester.widget<Switch>(find.byKey(const Key('notify-reply'))).value,
        isTrue,
        reason: 'rolled back after the failed save',
      );
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('编辑资料 saves and returns to the updated profile', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> patches = <Map<String, dynamic>>[];
    _handler = (http.Request request) async {
      if (request.method == 'PATCH') {
        patches.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(<String, Object>{});
      }
      return request.url.path.endsWith('/users/me')
          ? _json(_me())
          : _json(<Object>[]);
    };
    await http.runWithClient(() async {
      await _pump(tester, const ProfilePage());
      await tester.tap(find.byKey(const Key('profile-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-profile-nickname')),
        '新昵称',
      );
      await tester.tap(find.byKey(const Key('edit-profile-save')));
      await tester.pumpAndSettle();

      expect(patches.single['nickname'], '新昵称');
      expect(find.byKey(const Key('edit-profile-save')), findsNothing);
      expect(find.text('新昵称'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, () => _client);
  });

  testWidgets('tapping a theme card switches the theme', (
    WidgetTester tester,
  ) async {
    await AppThemeStore.instance.init();
    await _pump(tester, const SettingsPage());
    expect(AppThemeStore.instance.themeKey, 'zhushachi');
    await tester.tap(find.byKey(const Key('theme-card-zhuqing')));
    await _settle(tester);
    expect(AppThemeStore.instance.themeKey, 'zhuqing');
    await AppThemeStore.instance.setThemeKey('zhushachi');
  });
}
