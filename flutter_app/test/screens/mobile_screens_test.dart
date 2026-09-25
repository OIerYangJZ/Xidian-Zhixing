// Android screens through the real router, for comparing with the handoff
// (App 与小程序 v3). Captures only run with ZX_SCREENS_OUT set.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/mobile/core/navigation/app_router.dart';
import 'package:xdu_treehole_web/mobile/core/theme/mobile_theme.dart';

import 'screen_capture.dart';

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

final Map<String, Object> _routes = <String, Object>{
  '/users/me': <String, Object>{
    'id': 'me',
    'nickname': '示例昵称',
    'college': '示例学院',
    'major': '示例专业',
    'verified': true,
    'userLevel': 2,
    'postCount': 12,
    'followingCount': 36,
    'followerCount': 20,
  },
  '/channels': <String>['学习交流', '求助问答', '吐槽日常'],
  '/posts': <String, Object>{
    'posts': <Object>[samplePosts()[0], samplePosts()[2], samplePosts()[1]],
  },
  '/messages/conversations': <Object>[
    <String, Object>{
      'id': 'c1',
      'peerUserId': 'u1',
      'name': '林小舟',
      'lastMessage': '可以，周三晚上我都有空。',
      'timeText': '09:55',
      'unreadCount': 2,
    },
    <String, Object>{
      'id': 'c2',
      'peerUserId': 'u2',
      'name': '陈同学',
      'lastMessage': '示例：好的，到时候见。',
      'timeText': '昨天',
      'unreadCount': 1,
    },
    <String, Object>{
      'id': 'c3',
      'peerUserId': 'u3',
      'name': '周同学',
      'lastMessage': '示例：谢谢你的笔记！',
      'timeText': '09-20',
    },
    <String, Object>{
      'id': 'c4',
      'peerUserId': 'u4',
      'name': '王同学',
      'lastMessage': '对方已屏蔽你，只能查看历史消息',
      'timeText': '09-18',
      'blockedByPeer': true,
    },
  ],
  '/users/me/followers': <Object>[<String, Object>{'userId': 'u1', 'nickname': '林小舟', 'isFollowing': true, 'isFollower': true}],
  '/users/me/following': <Object>[<String, Object>{'userId': 'u1', 'nickname': '林小舟', 'isFollowing': true, 'isFollower': true}, <String, Object>{'userId': 'u2', 'nickname': '组队小王', 'isFollowing': true}],
  '/posts/p2': samplePosts()[1],
  '/posts/p2/view': <String, Object>{'viewCount': 96},
  '/users/u1': <String, Object>{'id': 'u1', 'nickname': '林小舟', 'userLevelLabel': 'Lv.3', 'bio': '示例签名：建模、跑步、偶尔写点东西。', 'college': '示例学院', 'major': '示例专业', 'postCount': 12, 'followingCount': 36, 'followerCount': 20, 'canFollow': true, 'canDirectMessage': true},
  '/posts/p2/comments': <Object>[
    <String, Object>{'id': 'k1', 'postId': 'p2', 'content': '已经修好了，感谢楼下提醒！', 'authorAlias': '安静的同学', 'isPostAuthor': true, 'likeCount': 6, 'createdAt': _ago(const Duration(minutes: 5))},
    <String, Object>{'id': 'k2', 'postId': 'p2', 'content': '示例：东侧还有两个没修。', 'authorAlias': '路过的同学', 'likeCount': 1, 'createdAt': _ago(const Duration(minutes: 3))},
  ],
  '/messages/conversations/c1/messages': <Object>[
    <String, Object>{'id': 'm1', 'content': '示例：你好，方便聊聊比赛安排吗？', 'createdAt': _ago(const Duration(minutes: 30)), 'senderAlias': '林小舟'},
    <String, Object>{'id': 'm2', 'content': '可以，周三晚上我都有空。', 'createdAt': _ago(const Duration(minutes: 27)), 'fromMe': true, 'isRead': true},
  ],
  '/messages/requests': <Object>[
    <String, Object>{
      'id': 'r1',
      'fromAlias': '周同学',
      'reason': '示例：看到你在找建模队友，想了解一下。',
      'status': 'pending',
    },
  ],
  '/notifications': <String, Object>{
    'items': <Object>[
      <String, Object>{
        'id': 'n1',
        'type': 'comment',
        'actorAlias': '安静的同学',
        'content': '示例：四楼靠窗那排上周已经修好了。',
        'relatedType': 'post',
        'postId': 'p2',
        'createdAt': _ago(const Duration(minutes: 8)),
        'timeText': '8 分钟前',
      },
      <String, Object>{
        'id': 'n2',
        'type': 'like',
        'actorAlias': '组队小王',
        'relatedType': 'post',
        'postId': 'p3',
        'createdAt': _ago(const Duration(hours: 1)),
        'timeText': '1 小时前',
      },
      <String, Object>{
        'id': 'n3',
        'type': 'report_result',
        'title': '举报处理结果：你举报的评论已删除',
        'content': '感谢你帮助维护社区。',
        'relatedType': 'report',
        'createdAt': _ago(const Duration(days: 2)),
        'readAt': _ago(const Duration(days: 1)),
        'timeText': '2 天前',
      },
    ],
    'unreadCount': 2,
  },
};

final http.Client _client = MockClient((http.Request request) async {
  final String path = request.url.path.replaceFirst('/api', '');
  return http.Response(
    jsonEncode(<String, Object>{'data': _routes[path] ?? <String, Object>{}}),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
});

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthStore.instance.init();
    await AuthStore.instance.saveToken('demo-token');
  });

  for (final (String name, String location) in <(String, String)>[
    ('home', '/'),
    ('messages', '/messages'),
    ('profile', '/profile'),
    ('post', '/post/p2'),
    ('chat', '/chat/c1?name=林小舟&userId=u1'),
    ('notifications', '/notifications'),
    ('search', '/search'),
    ('settings', '/profile/settings'),
    ('display', '/profile/settings/display'),
    ('user', '/user/u1'),
    ('create', '/post/create'),
  ]) {
    for (final Brightness b in Brightness.values) {
      testWidgets('android $name ${b.name}', (WidgetTester tester) async {
        await http.runWithClient(() async {
          tester.view.devicePixelRatio = 2;
          tester.view.physicalSize = phone * 2;
          addTearDown(tester.view.reset);
          final GlobalKey boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: MobileTheme.getThemeData(
                    'zhushachi',
                    const Locale('zh', 'CN'),
                    brightness: b,
                  ),
                  localizationsDelegates:
                      const <LocalizationsDelegate<dynamic>>[
                        AppLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                  supportedLocales: const <Locale>[
                    Locale('zh', 'CN'),
                    Locale('en'),
                  ],
                  locale: const Locale('zh', 'CN'),
                  routerConfig: appRouter,
                ),
              ),
            ),
          );
          appRouter.go(location);
          for (int i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          // Asset images (tab icons) decode off the fake clock.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          await tester.pump();
          await saveBoundary(tester, boundary, 'android_${name}_${b.name}');
        }, () => _client);
      }, skip: !capturing);
    }
  }
}
