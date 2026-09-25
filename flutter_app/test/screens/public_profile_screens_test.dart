import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/features/profile/public_user_profile_page.dart';

import 'screen_capture.dart';

/// AppRepositories keeps the first client it is given, so one client
/// serves every capture and [_blocked] switches the state.
bool _blocked = false;
final http.Client _client = MockClient((http.Request request) async {
  final Map<String, Object> routes = <String, Object>{
    '/users/u-lin': <String, Object>{
      'id': 'u-lin',
      'nickname': '林小舟',
      'userLevelLabel': 'Lv.3',
      'bio': '示例签名：建模、跑步、偶尔写点东西。',
      'college': '示例学院',
      'major': '示例专业',
      'postCount': 12,
      'followingCount': 36,
      'followerCount': 20,
      'canFollow': true,
      'canDirectMessage': !_blocked,
      'isBlockedByMe': _blocked,
    },
    '/posts': <Object>[samplePosts()[2], samplePosts()[0]],
  };
  return http.Response(
    jsonEncode(
      routes[request.url.path.replaceFirst('/api', '')] ?? <String, Object>{},
    ),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
});

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Size size,
    Brightness b, {
    bool blocked = false,
  }) {
    _blocked = blocked;
    return http.runWithClient(
      () => captureScreen(
        tester,
        name: name,
        home: const PublicUserProfilePage(userId: 'u-lin'),
        size: size,
        brightness: b,
      ),
      () => _client,
    );
  }

  testWidgets('public profile desktop', (WidgetTester tester) async {
    await shot(
      tester,
      'public_profile_desktop_light',
      desktop,
      Brightness.light,
    );
  }, skip: !capturing);
  testWidgets('public profile phone', (WidgetTester tester) async {
    await shot(
      tester,
      'public_profile_phone_light',
      const Size(390, 1200),
      Brightness.light,
    );
  }, skip: !capturing);
  testWidgets('public profile blocked', (WidgetTester tester) async {
    await shot(
      tester,
      'public_profile_blocked_phone_dark',
      phone,
      Brightness.dark,
      blocked: true,
    );
  }, skip: !capturing);
}
