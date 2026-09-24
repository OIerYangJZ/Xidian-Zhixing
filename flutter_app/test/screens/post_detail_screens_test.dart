import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:xdu_treehole_web/features/post/post_detail_page.dart';
import 'package:xdu_treehole_web/models/post_item.dart';

import 'screen_capture.dart';

Map<String, Object?> _post() => <String, Object?>{
  ...samplePosts()[2],
  'viewCount': 128,
  'canMessageAuthor': true,
  'content':
      '示例正文：我们队目前两个人，一个负责建模、一个负责编程，还缺一位擅长写作和排版的同学。比赛时间是十月中旬，每周线下讨论一次，地点在图书馆研讨间。',
};

List<Map<String, Object?>> _comments() => <Map<String, Object?>>[
  <String, Object?>{
    'id': 'c1',
    'authorAlias': '晨跑的鹿',
    'isAnonymous': true,
    'content': '示例：大二，写过两次课程论文，LaTeX 会一点，可以聊聊。',
    'likeCount': 5,
    'createdAt': '2026-09-23T10:02:00+08:00',
  },
  // The API returns comments flat; the page builds the thread from parentId.
  <String, Object?>{
    'id': 'c2',
    'parentId': 'c1',
    'authorAlias': '林小舟',
    'authorUserId': 'u-lin',
    'isPostAuthor': true,
    'content': '欢迎！已私信你。',
    'likeCount': 2,
    'liked': true,
    'createdAt': '2026-09-23T10:20:00+08:00',
  },
  <String, Object?>{
    'id': 'c3',
    'authorAlias': '北门的风',
    'authorUserId': 'u-wind',
    'content': '示例：我也想参加，还有名额吗？',
    'likeCount': 0,
    'createdAt': '2026-09-23T11:15:00+08:00',
  },
];

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  for (final (String name, Size size) in <(String, Size)>[
    ('desktop', desktop),
    ('phone', phone),
  ]) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('post detail $name ${brightness.name}', (
        WidgetTester tester,
      ) async {
        final http.Client client = sampleHttpClient(<String, Object>{
          '/posts/p3': _post(),
          '/posts/p3/comments': _comments(),
          '/posts/p3/view': <String, Object>{'viewCount': 128},
        });
        // PostDetailPage reads the static AppRepositories client, which is
        // created on first use; inside runWithClient it gets the mock.
        await http.runWithClient(
          () => captureScreen(
            tester,
            name: 'post_detail_${name}_${brightness.name}',
            home: PostDetailPage(post: PostItem.fromJson(_post())),
            size: size,
            brightness: brightness,
          ),
          () => client,
        );
      }, skip: !capturing);
    }
  }
}
