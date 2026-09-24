import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/navigation/share_links.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/auth/login_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget home, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
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
  await tester.pump();
}

void main() {
  for (final double width in <double>[390, 1440]) {
    testWidgets('a shared link says what opens after sign-in at $width', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const LoginPage(debugShareLink: ShareLink.post('p3')),
        width,
      );
      expect(find.byKey(const Key('login-share-card')), findsOneWidget);
      expect(find.text('登录后将打开分享的帖子'), findsOneWidget);
    });
  }

  testWidgets('a shared profile link names the profile', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const LoginPage(debugShareLink: ShareLink.user('u1')),
      1440,
    );
    expect(find.text('登录后将打开分享的主页'), findsOneWidget);
  });

  testWidgets('no share card without a shared link', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const LoginPage(), 1440);
    expect(find.byKey(const Key('login-share-card')), findsNothing);
  });
}
