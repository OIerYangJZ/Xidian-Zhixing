import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/state/app_theme_store.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/core/theme/shared_colors.dart';
import 'package:xdu_treehole_web/core/widgets/async_page_state.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/core/widgets/theme_dropdown.dart';
import 'package:xdu_treehole_web/features/auth/login_page.dart';
import 'package:xdu_treehole_web/features/common/access_state_page.dart';
import 'package:xdu_treehole_web/features/post/create_post_controller.dart';
import 'package:xdu_treehole_web/features/post/create_post_page.dart';
import 'package:xdu_treehole_web/features/profile/settings_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/home_shell.dart';
import 'package:xdu_treehole_web/widgets/post_card.dart';
import 'package:xdu_treehole_web/models/section_item.dart';

void main() {
  group('color theme catalog', () {
    test('current theme is named 人本·初创 and palettes are distinct', () {
      expect(AppColorThemes.defaultKey, 'zhushachi');
      expect(
        AppColorThemes.optionFor(AppColorThemes.defaultKey).labelZh,
        '人本·初创',
      );
      expect(AppColorThemes.options, hasLength(4));
      expect(
        AppColorThemes.lightFor('zhushachi').primary,
        isNot(AppColorThemes.lightFor('zhuqing').primary),
      );
      expect(
        AppColorThemes.lightFor('zhuqing').primary,
        isNot(AppColorThemes.lightFor('xingrenhuang').primary),
      );
    });

    testWidgets('dropdown exposes every theme and reports selection', (
      WidgetTester tester,
    ) async {
      String selectedKey = AppColorThemes.defaultKey;
      await tester.pumpWidget(
        _app(
          Material(
            child: Center(
              child: SizedBox(
                width: 360,
                child: ThemeDropdown(
                  themeKey: selectedKey,
                  locale: const Locale('zh', 'CN'),
                  expanded: true,
                  onChanged: (String key) {
                    selectedKey = key;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('人本·初创'), findsWidgets);
      expect(find.text('书院·青绿'), findsOneWidget);
      expect(find.text('杏黄·纸韵'), findsOneWidget);
      expect(find.text('墨朱·新页'), findsOneWidget);

      await tester.tap(find.text('书院·青绿'));
      await tester.pumpAndSettle();
      expect(selectedKey, 'zhuqing');
    });

    test('stored legacy themes migrate and new selection persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'treehole_theme_key': 'haiyanqing',
      });
      await AppThemeStore.instance.init();
      expect(AppThemeStore.instance.themeKey, 'zhuqing');

      await AppThemeStore.instance.setThemeKey('xingrenhuang');
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString('treehole_theme_key'), 'xingrenhuang');

      await AppThemeStore.instance.setThemeKey(AppColorThemes.defaultKey);
    });
  });

  group('responsive web layout', () {
    testWidgets(
      'English login and settings contain no beta disclaimer labels',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _appWithLocale(const LoginPage(), const Locale('en')),
        );
        await tester.pump();

        expect(
          find.text('Let authentic campus voices be heard'),
          findsOneWidget,
        );
        expect(find.textContaining('Project beta'), findsNothing);
        expect(find.textContaining('Not an official'), findsNothing);

        await tester.pumpWidget(
          _appWithLocale(const SettingsPage(), const Locale('en')),
        );
        await tester.pump();

        expect(find.text('Appearance and preferences'), findsOneWidget);
        expect(find.text('Rules and privacy'), findsOneWidget);
        expect(find.text('Access information'), findsNothing);
        expect(find.textContaining('内测'), findsNothing);
        expect(find.textContaining('非官方'), findsNothing);
      },
    );

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

        // Wide: tagline beside the sign-in card; narrow: brand over a panel.
        if (width >= 900) {
          expect(find.text('登录西电知行'), findsOneWidget);
        } else {
          expect(find.text('登录西电知行'), findsNothing);
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
        sectionType: 'club',
        sectionId: 'club-long',
        sectionName: '一个名称非常长的校园分区',
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

    testWidgets('remote discussion UI is an additional selectable shell', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppThemeStore.instance.setThemeKey('mozhuxinye');
      final ApiClient apiClient = _emptyApiClient();
      _setViewport(tester, width: 1280, height: 900);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            postRepositoryProvider.overrideWithValue(PostRepository(apiClient)),
          ],
          child: _app(const HomeShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discussion-ui-shell')), findsOneWidget);
      expect(
        find.byKey(const Key('desktop-primary-navigation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('discussion-feed-list')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await AppThemeStore.instance.setThemeKey(AppColorThemes.defaultKey);
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
    testWidgets('signing in requires accepting the terms first', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, width: 390, height: 820);
      await tester.pumpWidget(_app(const LoginPage()));

      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(find.byKey(const Key('login-agreement-hint')), findsOneWidget);
      // Nothing was started: the button is not in its busy state.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byKey(const Key('login-agreement')));
      await tester.pump();
      expect(find.byKey(const Key('login-agreement-hint')), findsNothing);
      expect(
        tester.widget<Checkbox>(find.byKey(const Key('login-agreement'))).value,
        isTrue,
      );
    });

    testWidgets('login page only offers the official authentication redirect', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, width: 390, height: 820);
      await tester.pumpWidget(_app(const LoginPage()));

      expect(find.byKey(const Key('official-auth-notice')), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      expect(find.byKey(const Key('login-identifier')), findsNothing);
      expect(find.byKey(const Key('login-password')), findsNothing);
      expect(find.text('注册账号'), findsNothing);
      expect(find.text('忘记密码'), findsNothing);
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

      // 发布 sits in the app bar, reachable without scrolling.
      await tester.tap(find.byKey(const Key('create-post-submit')));
      await tester.pumpAndSettle();

      // Every missing field is reported at once, with a summary on top.
      expect(find.byKey(const Key('create-post-error-summary')), findsOneWidget);
      expect(find.text('还有 2 项需要填写'), findsOneWidget);
      expect(find.text('请填写标题'), findsOneWidget);
      expect(find.text('请输入正文'), findsOneWidget);
      // 分区 starts on 综合, the server's default section.
      expect(find.text('请选择分区'), findsNothing);
      final ChoiceChip general = tester.widget<ChoiceChip>(
        find.byKey(const Key('create-post-section-general')),
      );
      expect(general.selected, isTrue);
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

      final ZxButton submit = tester.widget<ZxButton>(
        find.byKey(const Key('create-post-submit')),
      );
      expect(submit.onPressed, isNull);
      expect(submit.loading, isTrue);
      expect(find.text('发布中...'), findsWidgets);
    });

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
  return _appWithLocale(home, const Locale('zh', 'CN'));
}

Widget _appWithLocale(Widget home, Locale locale) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
    locale: locale,
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
      sections: const <SectionItem>[
        SectionItem(
          sectionType: 'general',
          sectionId: 'general',
          sectionName: '综合',
        ),
      ],
      loadingSections: false,
      submitting: submitting,
      progressText: submitting ? '发布中...' : null,
    );
  }

  @override
  Future<void> loadSections() async {}
}
