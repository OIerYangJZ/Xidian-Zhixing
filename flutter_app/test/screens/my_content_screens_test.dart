import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:xdu_treehole_web/features/legal/community_guidelines_page.dart';
import 'package:xdu_treehole_web/features/legal/terms_of_service_page.dart';
import 'package:xdu_treehole_web/features/me/my_comments_page.dart';
import 'package:xdu_treehole_web/features/me/my_favorites_page.dart';
import 'package:xdu_treehole_web/features/me/my_posts_page.dart';
import 'package:xdu_treehole_web/features/me/my_reports_page.dart';
import 'package:xdu_treehole_web/features/me/report_detail_page.dart';
import 'package:xdu_treehole_web/models/report_item.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  final Map<String, Object> report = <String, Object>{
    'id': 'r-20260920-01',
    'targetType': 'post',
    'targetId': 'p3',
    'targetTitle': '示例：出一辆自行车，九成新',
    'reason': '广告营销',
    'description': '示例：同一内容一天内发了五次。',
    'status': 'resolved',
    'result': '已删除内容',
    'createdAt': '2026-09-20 14:02',
    'handledAt': '2026-09-20 18:30',
  };
  final http.Client client = sampleHttpClient(<String, Object>{
    '/posts/mine': <Object>[samplePosts()[3], samplePosts()[2]],
    '/posts/favorites': <Object>[samplePosts()[1], samplePosts()[2]],
    '/channels': <String>['学习交流', '求助问答', '吐槽日常'],
    '/comments/mine': <Object>[
      <String, Object>{
        'id': 'c1',
        'postId': 'p3',
        'postTitle': '示例：数学建模校赛组队，缺一位会写论文的同学',
        'content': '示例：我写过两次建模论文，可以一起聊聊。',
        'timeText': '1 小时前',
      },
      <String, Object>{
        'id': 'c2',
        'postId': 'p2',
        'postTitle': '示例：图书馆四楼靠窗那排插座修好了吗？',
        'content': '示例：上周已经修好了，东侧还有两个没修。',
        'timeText': '昨天',
      },
    ],
    '/reports/mine': <Object>[
      report,
      <String, Object>{
        'id': 'r2',
        'targetType': 'comment',
        'targetId': 'c8',
        'targetTitle': '示例：一条不友善的评论',
        'reason': '人身攻击',
        'status': 'pending',
        'createdAt': '2026-09-24 09:10',
      },
    ],
    '/reports/r-20260920-01': report,
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home,
    Size size, [
    Brightness b = Brightness.light,
  ]) => http.runWithClient(
    () => captureScreen(
      tester,
      name: name,
      home: home,
      size: size,
      brightness: b,
    ),
    () => client,
  );

  testWidgets('terms desktop', (WidgetTester tester) async {
    await shot(
      tester,
      'legal_terms_desktop_light',
      const TermsOfServicePage(),
      desktop,
    );
  }, skip: !capturing);
  testWidgets('guidelines phone dark', (WidgetTester tester) async {
    await shot(
      tester,
      'legal_guidelines_phone_dark',
      const CommunityGuidelinesPage(),
      phone,
      Brightness.dark,
    );
  }, skip: !capturing);
  testWidgets('my posts', (WidgetTester tester) async {
    await shot(
      tester,
      'my_posts_phone_light',
      const MyPostsPage(),
      const Size(390, 1200),
    );
  }, skip: !capturing);
  testWidgets('my favorites', (WidgetTester tester) async {
    await shot(
      tester,
      'my_favorites_desktop_light',
      const MyFavoritesPage(),
      desktop,
    );
  }, skip: !capturing);
  testWidgets('my comments', (WidgetTester tester) async {
    await shot(
      tester,
      'my_comments_phone_dark',
      const MyCommentsPage(),
      phone,
      Brightness.dark,
    );
  }, skip: !capturing);
  testWidgets('my reports', (WidgetTester tester) async {
    await shot(tester, 'my_reports_phone_light', const MyReportsPage(), phone);
  }, skip: !capturing);
  testWidgets('report detail', (WidgetTester tester) async {
    await shot(
      tester,
      'report_detail_phone_light',
      ReportDetailPage(report: ReportItem.fromJson(report)),
      phone,
    );
  }, skip: !capturing);
}
