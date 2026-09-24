import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/navigation/share_links.dart';
import 'package:xdu_treehole_web/features/auth/login_page.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  const ShareLink link = ShareLink.post('p3');

  for (final (String name, Size size, Brightness b, ShareLink? share)
      in <(String, Size, Brightness, ShareLink?)>[
        ('desktop_light', const Size(1440, 900), Brightness.light, link),
        ('desktop_dark', const Size(1440, 900), Brightness.dark, null),
        ('phone_light', phone, Brightness.light, link),
      ]) {
    testWidgets('login $name', (WidgetTester tester) async {
      await captureScreen(
        tester,
        name: 'login_$name',
        home: LoginPage(debugShareLink: share),
        size: size,
        brightness: b,
      );
    }, skip: !capturing);
  }

  testWidgets('login without consent', (WidgetTester tester) async {
    await captureScreen(
      tester,
      name: 'login_no_consent_phone_dark',
      home: const LoginPage(),
      size: phone,
      brightness: Brightness.dark,
      beforeCapture: () async {
        await tester.tap(find.byKey(const Key('login-submit')));
        await tester.pumpAndSettle();
      },
    );
  }, skip: !capturing);
}
