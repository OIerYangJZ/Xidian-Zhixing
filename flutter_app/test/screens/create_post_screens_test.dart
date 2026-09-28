import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/features/post/create_post_controller.dart';
import 'package:xdu_treehole_web/features/post/create_post_page.dart';
import 'package:xdu_treehole_web/models/section_item.dart';

import 'screen_capture.dart';

class _ReadyController extends CreatePostController {
  _ReadyController(super.ref) {
    state = const CreatePostState(
      sections: <SectionItem>[
        SectionItem(
          sectionType: 'general',
          sectionId: 'general',
          sectionName: '综合',
        ),
        SectionItem(
          sectionType: 'college',
          sectionId: 'cs',
          sectionName: '计算机科学与技术学院',
        ),
      ],
      loadingSections: false,
      isLevelOneUser: true,
    );
  }

  @override
  Future<void> loadSections() async {}
}

const Map<String, Object> _draft = <String, Object>{
  'title': '示例：数学建模校赛组队，缺一位会写论文的同学',
  'content':
      '我们队目前**两个人**，一个负责建模、一个负责编程，还缺一位擅长写作和排版的同学。\n\n## 安排\n- 时间：十月中旬\n- 地点：图书馆研讨间',
  'markdown': true,
  'sectionKey': 'general',
  'status': 'ongoing',
  'anonymous': true,
  'anonymousAlias': '晨跑的鹿',
  'tags': <String>['组队', '竞赛'],
};

void main() {
  setUpAll(() async {
    if (capturing) await loadScreenFonts();
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    Brightness brightness, {
    bool withDraft = true,
    bool submitEmpty = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (withDraft) 'xiaodian_create_post_draft': jsonEncode(_draft),
    });
    await captureScreen(
      tester,
      name: name,
      home: const CreatePostPage(),
      size: size,
      brightness: brightness,
      overrides: <Override>[
        createPostControllerProvider.overrideWith((Ref ref) => _ReadyController(ref)),
      ],
      beforeCapture: submitEmpty
          ? () async {
              await tester.tap(find.byKey(const Key('create-post-submit')));
              await tester.pumpAndSettle();
            }
          : null,
    );
  }

  testWidgets('create post desktop dark', (WidgetTester tester) async {
    await capture(tester, 'create_post_desktop_dark', desktop, Brightness.dark);
  }, skip: !capturing);
  testWidgets('create post phone light', (WidgetTester tester) async {
    await capture(tester, 'create_post_phone_light', phone, Brightness.light);
  }, skip: !capturing);
  testWidgets('create post phone errors', (WidgetTester tester) async {
    await capture(
      tester,
      'create_post_phone_errors',
      phone,
      Brightness.light,
      withDraft: false,
      submitEmpty: true,
    );
  }, skip: !capturing);
}
