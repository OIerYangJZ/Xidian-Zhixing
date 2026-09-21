import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/ai/ai_page.dart';
import 'package:xdu_treehole_web/features/campus/campus_page.dart';
import 'package:xdu_treehole_web/features/feed/feed_controller.dart';
import 'package:xdu_treehole_web/features/feed/feed_page.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/models/campus_models.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/campus_repository.dart';
import 'package:xdu_treehole_web/widgets/discussion_home_scaffold.dart';

// Renderer captures of real production widgets. These do not assert pixel parity
// with the HTML artifact; review the generated images separately.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final entry in {
      'Times New Roman': 'TimesNewRoman.ttf',
      'STZhongsong': 'STZhongsong.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });
  for (final width in [390.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final entry in <String, Widget>{
        'feed': const FeedPage(),
        'campus': const CampusPage(),
        'ai': const AiPage(),
      }.entries) {
        testWidgets('${entry.key} ${width.toInt()} ${dark ? "dark" : "light"}', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, width < 800 ? 844 : 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          final locale = width < 800
              ? const Locale('zh', 'CN')
              : const Locale('en');
          final base = AppTheme.referenceThemeFor(
              locale, dark ? Brightness.dark : Brightness.light);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                feedControllerProvider.overrideWith((ref) => _ReviewFeed(ref)),
                campusRepositoryProvider.overrideWithValue(_ReviewCampus()),
              ],
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: base.copyWith(
                    textTheme: base.textTheme.apply(
                      fontFamily: 'Times New Roman',
                      fontFamilyFallback: ['STZhongsong'],
                    ),
                  ),
                  home: DiscussionHomeScaffold(
                    currentIndex: entry.key == 'campus'
                        ? 1
                        : entry.key == 'ai'
                        ? 2
                        : 0,
                    content: entry.value,
                    notificationUnreadCount: 8,
                    onSelect: (_) {},
                    onCreate: () {},
                    onFilter: () {},
                    onSearch: () {},
                    onNotifications: () {},
                    onMessages: () {},
                    onSettings: () {},
                    onProfile: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('artifacts/reference-review')
              ..createSync(recursive: true);
            File(
              '${directory.path}/${entry.key}-${width.toInt()}-${dark ? "dark" : "light"}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}

class _ReviewFeed extends FeedController {
  _ReviewFeed(super.ref) {
    state = FeedState(
      loading: false,
      channels: const ['全部', '综合'],
      posts: [
        PostItem(
          id: 'visual-fixture',
          title: '今天的校园 / A day on campus',
          content:
              '在这里分享生活，也听见彼此。\nA place for everyday thoughts and conversations.',
          channel: '综合',
          tags: const [],
          authorAlias: 'Campus reader',
          createdAt: DateTime(2026, 9, 20, 8),
          hasImage: false,
          commentCount: 12,
          likeCount: 32,
          favoriteCount: 4,
          status: PostStatus.ongoing,
          allowComment: true,
          allowDm: false,
        ),
      ],
    );
  }
}

class _ReviewCampus extends CampusRepository {
  _ReviewCampus() : super(ApiClient());
  @override
  Future<List<CampusService>> fetchServices() async => [
    for (final entry in [
      ['classtable', '课表'],
      ['score', '成绩单'],
      ['exam', '考试安排'],
      ['experiment', '实验安排'],
    ])
      CampusService.fromJson({
        'id': entry[0],
        'slug': entry[0],
        'name': entry[1],
        'groupId': 'study',
        'groupName': '学习事务',
        'kind': 'schedule',
        'iconKey': 'calendar',
        'actions': [
          {'type': 'calendar', 'label': '查看周历'},
        ],
      }),
  ];
  @override
  Future<CampusTodaySchedules> fetchTodaySchedules() async =>
      const CampusTodaySchedules(date: '2026-09-20', items: []);
}
