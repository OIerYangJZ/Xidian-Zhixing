import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/navigation/share_links.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/auth/banned_account_page.dart';
import 'package:xdu_treehole_web/features/post/post_unavailable_page.dart';
import 'package:xdu_treehole_web/repositories/appeal_repository.dart';

import 'screen_capture.dart';

class _Appeals extends AppealRepository {
  _Appeals(this.status) : super(ApiClient());

  final String status;

  @override
  Future<AppealState> fetchLatest() async =>
      AppealState.fromJson(<String, dynamic>{
        'banned': true,
        'supportEmail': 'support@示例.edu.cn',
        'appeal': <String, dynamic>{
          'status': status,
          'content': status == 'pending' ? '示例：那条帖子不是我发的，账号当天在别处登录过。' : '',
          'adminNote': status == 'rejected' ? '示例：证据不足' : '',
        },
      });
}

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  for (final (String name, String status, Brightness b)
      in <(String, String, Brightness)>[
        ('form_light', '', Brightness.light),
        ('pending_light', 'pending', Brightness.light),
        ('rejected_dark', 'rejected', Brightness.dark),
      ]) {
    testWidgets('banned $name', (WidgetTester tester) async {
      await captureScreen(
        tester,
        name: 'banned_${name}',
        home: const BannedAccountPage(),
        size: phone,
        brightness: b,
        overrides: <Override>[
          appealRepositoryProvider.overrideWithValue(_Appeals(status)),
        ],
      );
    }, skip: !capturing);
  }

  for (final Brightness b in Brightness.values) {
    testWidgets('post unavailable ${b.name}', (WidgetTester tester) async {
      await captureScreen(
        tester,
        name: 'post_unavailable_phone_${b.name}',
        home: const PostUnavailablePage(link: ShareLink.post('48213')),
        size: phone,
        brightness: b,
      );
    }, skip: !capturing);
  }
}
