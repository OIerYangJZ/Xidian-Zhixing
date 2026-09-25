import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/features/download/android_release_page.dart';
import 'package:xdu_treehole_web/features/profile/emoji_settings_page.dart';
import 'package:xdu_treehole_web/features/profile/follow_list_page.dart';
import 'package:xdu_treehole_web/features/profile/notification_preferences_page.dart';
import 'package:xdu_treehole_web/features/profile/profile_page.dart';
import 'package:xdu_treehole_web/features/profile/settings_page.dart';

import 'screen_capture.dart';

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  final http.Client client = sampleHttpClient(<String, Object>{
    '/users/me': <String, Object>{
      'id': 'me',
      'nickname': '示例昵称',
      'studentId': '21009200137',
      'email': '示例邮箱@stu.xidian.edu.cn',
      'bio': '示例签名：在图书馆四楼靠窗的位置。',
      'gender': '男',
      'verified': true,
      'userLevel': 2,
      'isLevelOneUser': false,
      'favoriteCount': 8,
      'postCount': 12,
      'followingCount': 36,
      'followerCount': 20,
      'allowStrangerDm': true,
      'showContactable': false,
      'notifyComment': true,
      'notifyReply': true,
      'notifyLike': false,
      'notifyFavorite': true,
      'notifyReportResult': true,
      'notifySystem': true,
    },
    '/users/me/following': <Object>[
      <String, Object>{
        'userId': 'u1',
        'nickname': '林小舟',
        'isFollowing': true,
        'isFollower': true,
      },
      <String, Object>{'userId': 'u2', 'nickname': '组队小王', 'isFollowing': true},
    ],
    '/users/me/followers': <Object>[
      <String, Object>{
        'userId': 'u1',
        'nickname': '林小舟',
        'isFollowing': true,
        'isFollower': true,
      },
      <String, Object>{'userId': 'u3', 'nickname': '周同学', 'isFollower': true},
    ],
    '/users/me/friends': <Object>[],
    '/releases/android/latest': <String, Object>{
      'platform': 'android',
      'versionName': '1.4.0',
      'versionCode': 34,
      'releaseNotes': '示例：全新界面；私信规则调整；深色模式跟随系统。',
      'fileName': 'xidian-zhixing-1.4.0.apk',
      'sizeBytes': 31457280,
      'downloadUrl': '/downloads/android/latest.apk',
      'uploadedAt': '2026-09-25',
    },
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget home,
    Size size,
    Brightness b,
  ) {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return http.runWithClient(
      () => captureScreen(
        tester,
        name: name,
        home: home,
        size: size,
        brightness: b,
      ),
      () => client,
    );
  }

  for (final Brightness b in Brightness.values) {
    testWidgets('profile phone ${b.name}', (WidgetTester tester) async {
      await capture(
        tester,
        'profile_phone_${b.name}',
        const ProfilePage(),
        const Size(390, 1500),
        b,
      );
    }, skip: !capturing);

    testWidgets('settings phone ${b.name}', (WidgetTester tester) async {
      await capture(
        tester,
        'settings_phone_${b.name}',
        const SettingsPage(),
        const Size(390, 1080),
        b,
      );
    }, skip: !capturing);
  }

  testWidgets('profile desktop', (WidgetTester tester) async {
    await capture(
      tester,
      'profile_desktop_light',
      const ProfilePage(),
      const Size(1440, 1500),
      Brightness.light,
    );
  }, skip: !capturing);

  testWidgets('follow list phone', (WidgetTester tester) async {
    await capture(
      tester,
      'follow_list_phone_light',
      const FollowListPage(initialTab: FollowListTab.followers),
      phone,
      Brightness.light,
    );
  }, skip: !capturing);

  testWidgets('notification preferences phone', (WidgetTester tester) async {
    await capture(
      tester,
      'notification_preferences_phone_dark',
      const NotificationPreferencesPage(),
      phone,
      Brightness.dark,
    );
  }, skip: !capturing);

  testWidgets('emoji settings phone', (WidgetTester tester) async {
    await capture(
      tester,
      'emoji_settings_phone_dark',
      const EmojiSettingsPage(),
      phone,
      Brightness.dark,
    );
  }, skip: !capturing);

  testWidgets('android download phone', (WidgetTester tester) async {
    await capture(
      tester,
      'android_download_phone_light',
      const AndroidReleasePage(),
      phone,
      Brightness.light,
    );
  }, skip: !capturing);
}
