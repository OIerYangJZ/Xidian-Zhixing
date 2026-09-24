import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/home_shell.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  final Map<String, Size> sizes = <String, Size>{
    'desktop': desktop,
    'tablet': tablet,
    'phone': phone,
  };
  for (final MapEntry<String, Size> size in sizes.entries) {
    for (final Brightness brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      testWidgets('feed ${size.key} ${brightness.name}', (
        WidgetTester tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final PostRepository posts = PostRepository(
          sampleApiClient(<String, Object>{
            '/posts': <String, Object>{'posts': samplePosts()},
            '/channels': <String>['综合', '学习交流', '求助问答', '二手交易', '吐槽日常'],
          }),
        );
        await captureScreen(
          tester,
          name: 'feed_${size.key}_${brightness.name}',
          home: const HomeShell(),
          size: size.value,
          brightness: brightness,
          overrides: [postRepositoryProvider.overrideWithValue(posts)],
        );
      }, skip: !capturing);
    }
  }
}
