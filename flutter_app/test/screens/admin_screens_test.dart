import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/features/admin/admin_console_page.dart';
import 'package:xdu_treehole_web/features/admin/admin_login_page.dart';
import 'package:xdu_treehole_web/repositories/admin_repository.dart';

import 'screen_capture.dart';

AdminRepository _repo() => AdminRepository(
  sampleApiClient(<String, Object>{
    '/admin/auth/me': <String, Object>{
      'username': 'admin',
      'role': 'primary',
      'roleLabel': '一级管理员',
      'isPrimary': true,
    },
    '/admin/overview': <String, Object>{
      'todayNewUsers': 18,
      'todayPosts': 126,
      'todayComments': 402,
      'todayReports': 5,
      'pendingReviews': 3,
      'pendingCancellationRequests': 1,
      'pendingFeedbacks': 2,
      'activeUsers': 2310,
      'bannedUsers': 4,
      'mutedUsers': 2,
    },
    '/admin/channels-tags': <String, Object>{'tags': <String>['食堂', '二手']},
    '/admin/config': <String, Object>{
      'sensitiveWords': <String>[],
      'settings': <String, int>{
        'postRateLimit': 5,
        'commentRateLimit': 20,
        'messageRateLimit': 30,
        'imageMaxMB': 5,
      },
    },
    '/admin/reviews': <Object>[
      for (int i = 0; i < 3; i++)
        <String, Object>{
          'id': 'rv$i',
          'targetType': 'post',
          'title': '示例：待审核帖子 $i',
          'content': '示例正文',
          'authorAlias': '匿名同学',
          'createdAt': '2026-09-25 10:0$i',
          'reviewStatus': 'pending',
        },
    ],
    '/admin/reports': <Object>[
      <String, Object>{
        'id': 'r1',
        'targetType': 'post',
        'targetId': 'p3',
        'reason': '广告营销',
        'status': 'pending',
        'reporterAlias': '安静的同学',
        'createdAt': '2026-09-25 09:12',
      },
      <String, Object>{
        'id': 'r2',
        'targetType': 'comment',
        'targetId': 'c8',
        'reason': '人身攻击',
        'status': 'resolved',
        'result': '已删除内容',
        'createdAt': '2026-09-24 21:40',
      },
    ],
  }),
);

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  for (final Brightness b in Brightness.values) {
    testWidgets('admin desktop ${b.name}', (WidgetTester tester) async {
      await captureScreen(
        tester,
        name: 'admin_desktop_${b.name}',
        home: AdminConsolePage(repository: _repo()),
        size: desktop,
        brightness: b,
        themeKey: 'zhuqing',
      );
    }, skip: !capturing);
  }

  testWidgets('admin reports desktop', (WidgetTester tester) async {
    await captureScreen(
      tester,
      name: 'admin_reports_desktop_light',
      home: AdminConsolePage(repository: _repo()),
      size: desktop,
      themeKey: 'zhuqing',
      beforeCapture: () async {
        await tester.tap(find.byKey(const Key('admin-section-举报处理')));
        await tester.pumpAndSettle();
      },
    );
  }, skip: !capturing);

  testWidgets('admin phone', (WidgetTester tester) async {
    await captureScreen(
      tester,
      name: 'admin_phone_light',
      home: AdminConsolePage(repository: _repo()),
      size: phone,
      themeKey: 'zhuqing',
    );
  }, skip: !capturing);

  testWidgets('admin login', (WidgetTester tester) async {
    await captureScreen(
      tester,
      name: 'admin_login_phone_light',
      home: const AdminLoginPage(),
      size: phone,
    );
  }, skip: !capturing);
}
