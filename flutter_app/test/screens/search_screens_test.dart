import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/search/search_page.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/repositories/user_repository.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  List<Override> overrides({bool empty = false}) {
    final ApiClient client = sampleApiClient(<String, Object>{
      '/channels': <String>['全部', '学习交流', '求助问答', '吐槽日常'],
      '/posts': <String, Object>{
        'posts': empty
            ? <Object>[]
            : <Object>[samplePosts()[2], samplePosts()[1]],
      },
      '/users/search': empty
          ? <Object>[]
          : <Object>[
              <String, Object>{
                'id': 'u-lin',
                'nickname': '林小舟',
                'userLevelLabel': 'Lv.3',
                'postCount': 12,
                'followerCount': 20,
                'isFollowing': true,
                'isFollower': true,
                'canFollow': true,
              },
              <String, Object>{
                'id': 'u-2',
                'nickname': '组队小王',
                'userLevelLabel': 'Lv.1',
                'postCount': 3,
                'followerCount': 5,
                'canFollow': true,
              },
            ],
    });
    return <Override>[
      postRepositoryProvider.overrideWithValue(PostRepository(client)),
      userRepositoryProvider.overrideWithValue(UserRepository(client)),
    ];
  }

  for (final (String name, Size size, Brightness b)
      in <(String, Size, Brightness)>[
        ('desktop_light', desktop, Brightness.light),
        ('phone_dark', phone, Brightness.dark),
      ]) {
    testWidgets('search $name', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await captureScreen(
        tester,
        name: 'search_$name',
        home: const SearchPage(initialKeyword: '组队'),
        size: size,
        brightness: b,
        overrides: overrides(),
      );
    }, skip: !capturing);
  }

  testWidgets('search users phone', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await captureScreen(
      tester,
      name: 'search_users_phone_light',
      home: const SearchPage(initialKeyword: '组队'),
      size: phone,
      overrides: overrides(),
      beforeCapture: () async {
        await tester.tap(find.text('用户'));
        await tester.pumpAndSettle();
      },
    );
  }, skip: !capturing);

  testWidgets('search empty phone', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await captureScreen(
      tester,
      name: 'search_empty_phone_light',
      home: const SearchPage(initialKeyword: '量子速读社'),
      size: phone,
      overrides: overrides(empty: true),
    );
  }, skip: !capturing);
}
