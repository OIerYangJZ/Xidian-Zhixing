import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/notifications/notification_center_page.dart';
import 'package:xdu_treehole_web/repositories/notification_repository.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  String ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

  List<Override> overrides() => <Override>[
    notificationRepositoryProvider.overrideWithValue(
      NotificationRepository(
        sampleApiClient(<String, Object>{
          '/notifications': <String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': 'n1',
                'type': 'comment',
                'actorAlias': '安静的同学',
                'content': '示例：四楼靠窗那排上周已经修好了，东侧还有两个没修。',
                'relatedType': 'post',
                'postId': 'p2',
                'createdAt': ago(const Duration(minutes: 8)),
                'timeText': '8 分钟前',
              },
              <String, Object>{
                'id': 'n2',
                'type': 'reply',
                'actorAlias': '林小舟',
                'content': '示例：可以的，晚上一起讨论下选题？',
                'relatedType': 'comment',
                'postId': 'p3',
                'createdAt': ago(const Duration(minutes: 40)),
                'timeText': '40 分钟前',
              },
              <String, Object>{
                'id': 'n3',
                'type': 'like',
                'actorAlias': '组队小王',
                'relatedType': 'post',
                'postId': 'p3',
                'createdAt': ago(const Duration(minutes: 50)),
                'timeText': '50 分钟前',
                'isRead': true,
              },
              <String, Object>{
                'id': 'n4',
                'type': 'report_result',
                'content': '示例：你举报的内容经核实违反社区规范，已被处理。',
                'relatedType': 'report',
                'createdAt': ago(const Duration(days: 2)),
                'timeText': '2 天前',
              },
              <String, Object>{
                'id': 'n5',
                'type': 'system_announcement',
                'title': '示例：社区规范更新',
                'content': '示例：新增了关于二手交易的说明，请在发帖前阅读。',
                'createdAt': ago(const Duration(days: 3)),
                'timeText': '3 天前',
                'isRead': true,
              },
            ],
            'unreadCount': 3,
          },
        }),
      ),
    ),
  ];

  for (final (String name, Size size, Brightness b)
      in <(String, Size, Brightness)>[
        ('desktop_light', desktop, Brightness.light),
        ('desktop_dark', desktop, Brightness.dark),
        ('phone_light', phone, Brightness.light),
        ('phone_dark', phone, Brightness.dark),
      ]) {
    testWidgets('notifications $name', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await captureScreen(
        tester,
        name: 'notifications_$name',
        home: const NotificationCenterPage(),
        size: size,
        brightness: b,
        overrides: overrides(),
      );
    }, skip: !capturing);
  }
}
