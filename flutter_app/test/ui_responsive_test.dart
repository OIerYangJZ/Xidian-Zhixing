import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/core/widgets/async_page_state.dart';
import 'package:xdu_treehole_web/features/auth/login_page.dart';
import 'package:xdu_treehole_web/features/auth/verify_page.dart';
import 'package:xdu_treehole_web/features/common/access_state_page.dart';
import 'package:xdu_treehole_web/features/post/create_post_controller.dart';
import 'package:xdu_treehole_web/features/post/create_post_page.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/home_shell.dart';
import 'package:xdu_treehole_web/widgets/post_card.dart';

void main() {
  group('responsive web layout', () {
    for (final double width in <double>[360, 390, 768, 1280, 1440]) {
      testWidgets('login page has no overflow at ${width.toInt()}px', (
        WidgetTester tester,
      ) async {
        _setViewport(tester, width: width, height: 820);
        await tester.pumpWidget(_app(const LoginPage()));
        await tester.pump();

        expect(find.text('西电知行'), findsOneWidget);
        expect(find.byKey(const Key('login-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (width >= 960) {
          expect(find.text('阅读优先'), findsOneWidget);
        } else {
          expect(find.text('阅读优先'), findsNothing);
        }
      });
    }

    testWidgets('post card tolerates long identity and tags on 360px', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, width: 360, height: 760);
      final PostItem post = PostItem(
        id: 'long-content',
        title: '这是一个用于检查手机浏览器长标题自动换行且不会撑破页面的帖子标题',
        content: '正文同样需要在很窄的屏幕里保持可读，不应触发横向滚动。',
        channel: '一个名称非常长的校园分区',
        tags: const <String>['非常长的标签名称一', '非常长的标签名称二'],
        authorAlias: '一个非常非常长的校园社区用户名',
        createdAt: DateTime(2026, 7, 23),
        hasImage: false,
        commentCount: 2,
        likeCount: 3,
        favoriteCount: 1,
        status: PostStatus.ongoing,
        allowComment: true,
        allowDm: false,
      );

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[PostCard(post: post, onTap: () {})],
            ),
          ),
        ),
      );

      expect(find.textContaining('长标题自动换行'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation and states', () {
    testWidgets('shell switches between mobile and desktop navigation', (
      WidgetTester tester,
    ) async {
      final ApiClient apiClient = _emptyApiClient();
      final List<Override> overrides = <Override>[
        postRepositoryProvider.overrideWithValue(PostRepository(apiClient)),
      ];

      _setViewport(tester, width: 390, height: 820);
      await tester.pumpWidget(
        ProviderScope(overrides: overrides, child: _app(const HomeShell())),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-primary-navigation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('desktop-primary-navigation')), findsNothing);
      expect(find.text('树洞'), findsWidgets);

      _setViewport(tester, width: 1280, height: 900);
      await tester.pump();

      expect(
        find.byKey(const Key('desktop-primary-navigation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mobile-primary-navigation')), findsNothing);
      expect(find.byKey(const Key('create-post-fab')), findsOneWidget);
      expect(find.text('公告'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading and error states expose clear feedback and retry', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      await tester.pumpWidget(
        _app(
          AsyncPageState(
            loading: true,
            loadingLabel: '正在加载测试内容',
            error: null,
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.text('正在加载测试内容'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          AsyncPageState(
            loading: false,
            error: '网络连接失败',
            onRetry: () {
              retried = true;
            },
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(find.text('网络连接失败'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
    });

    testWidgets('unknown page provides a working 404 state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const AccessStatePage.notFound()));
      expect(find.text('页面没有找到'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('forms and authentication state', () {
    testWidgets('login form shows inline validation feedback', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, width: 390, height: 820);
      await tester.pumpWidget(_app(const LoginPage()));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();

      expect(find.byKey(const Key('login-error')), findsOneWidget);
      expect(find.text('请输入学号或学生邮箱。'), findsOneWidget);
    });

    testWidgets('create form validates required fields', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, width: 390, height: 820);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            createPostControllerProvider.overrideWith(
              (Ref ref) => _TestCreatePostController(ref),
            ),
          ],
          child: _app(const CreatePostPage()),
        ),
      );
      await tester.pump();

      final Finder submit = find.byKey(const Key('create-post-submit'));
      await tester.drag(
        find.byKey(const Key('create-post-form-scroll')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('请输入标题'), findsOneWidget);
      expect(find.text('请输入正文'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('create form disables submit while loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            createPostControllerProvider.overrideWith(
              (Ref ref) => _TestCreatePostController(ref, submitting: true),
            ),
          ],
          child: _app(const CreatePostPage()),
        ),
      );
      await tester.pump();

      final FilledButton submit = tester.widget<FilledButton>(
        find.byKey(const Key('create-post-submit')),
      );
      expect(submit.onPressed, isNull);
      expect(find.text('发布中...'), findsWidgets);
    });

    testWidgets(
      'verification input keeps leading zero without numeric conversion',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(const VerifyPage(campusEmail: 'student@stu.xidian.edu.cn')),
        );

        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '012345',
        );

        final TextField field = tester.widget<TextField>(
          find.byKey(const Key('verification-code-input')),
        );
        expect(field.controller!.text, '012345');
      },
    );

    test('saved login token restores authenticated state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'xdu_treehole_auth_token': 'restored-test-token',
      });
      await AuthStore.instance.init();
      expect(AuthStore.instance.isAuthenticated, isTrue);
      expect(AuthStore.instance.token, 'restored-test-token');
      await AuthStore.instance.clear();
    });
  });
}

Widget _app(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: home,
  );
}

void _setViewport(
  WidgetTester tester, {
  required double width,
  required double height,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ApiClient _emptyApiClient() {
  return ApiClient(
    httpClient: MockClient((http.Request request) async {
      final Object response = switch (request.url.path) {
        '/api/channels' => <String>['综合', '求助问答'],
        '/api/posts' => <String, Object>{'posts': <Object>[]},
        _ => <String, Object>{},
      };
      return http.Response(
        jsonEncode(response),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }),
  );
}

class _TestCreatePostController extends CreatePostController {
  _TestCreatePostController(Ref ref, {bool submitting = false}) : super(ref) {
    state = CreatePostState(
      channels: const <String>['综合'],
      loadingChannels: false,
      submitting: submitting,
      progressText: submitting ? '发布中...' : null,
    );
  }

  @override
  Future<void> loadChannels() async {}
}
