// Shared harness for rendering real screens to PNG, for comparing pages with
// the Claude Design handoff while migrating them. Captures only run when
// ZX_SCREENS_OUT names an output directory:
//
//   ZX_SCREENS_OUT=/tmp/zx-screens flutter test test/screens/
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/design_system/zx_metrics.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';

final String? screensOut = Platform.environment['ZX_SCREENS_OUT'];
bool get capturing => screensOut != null;

/// Viewports from the handoff's page frames.
const Size desktop = Size(1440, 960);
const Size tablet = Size(768, 1024);
const Size phone = Size(390, 844);

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    final File file = File(path);
    if (file.existsSync()) {
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

/// Real fonts instead of the test harness's placeholder boxes. The bundled
/// web sans stands in for the default family, as on web.
Future<void> loadScreenFonts() async {
  // Render with the web font stack (ZxSans, then STSong), as web does.
  ZxFonts.debugWebFonts = true;
  final String sdk = '${Platform.environment['HOME']}/flutter';
  await _loadFont('MaterialIcons', <String>[
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  await _loadFont('STZhongsong', <String>['assets/fonts/STZhongsong.ttf']);
  await _loadFont('STSong', <String>['assets/fonts/STSong.ttf']);
  // PingFang SC heads ZxFonts.bodyFallback, which is what text with no
  // family of its own resolves through (app bar titles, segmented buttons).
  for (final String family in <String>[
    'ZxSans',
    'Roboto',
    'FlutterTest',
    'PingFang SC',
  ]) {
    await _loadFont(family, <String>[
      'assets/fonts/ZxSans-Regular.ttf',
      'assets/fonts/ZxSans-SemiBold.ttf',
    ]);
  }
}

/// Canned API answers for the screens. [routes] maps a path under /api to a
/// JSON body; anything else answers with an empty object.
http.Client sampleHttpClient(Map<String, Object> routes) {
  return MockClient((http.Request request) async {
    final String path = request.url.path.replaceFirst('/api', '');
    return http.Response(
      jsonEncode(routes[path] ?? <String, Object>{}),
      200,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  });
}

ApiClient sampleApiClient(Map<String, Object> routes) =>
    ApiClient(httpClient: sampleHttpClient(routes));

/// Pumps [home] at [size] in [brightness] and writes `<name>.png`.
Future<void> captureScreen(
  WidgetTester tester, {
  required String name,
  required Widget home,
  required Size size,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const <Override>[],
  String themeKey = 'zhushachi',

  /// Interactions to run before the capture, e.g. tapping submit.
  Future<void> Function()? beforeCapture,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  final GlobalKey boundary = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.designSystemFor(
            themeKey: themeKey,
            brightness: brightness,
          ),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
          locale: const Locale('zh', 'CN'),
          home: home,
        ),
      ),
    ),
  );
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (beforeCapture != null) {
    await beforeCapture();
  }
  await saveBoundary(tester, boundary, name);
}

/// Writes the pixels under [boundary] to `<name>.png`.
Future<void> saveBoundary(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await render.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(screensOut!).createSync(recursive: true);
    File('$screensOut/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Sample posts covering every marker the card must show. Contents are
/// examples, as in the handoff.
List<Map<String, Object?>> samplePosts() => <Map<String, Object?>>[
  <String, Object?>{
    'id': 'p1',
    'title': '示例：本周四起图书馆延长开放至 23:00',
    'content': '期末周图书馆开放时间调整，具体以学校通知为准。',
    'channel': '综合',
    'authorAlias': '示例：教务通知转载',
    'authorId': 'u-office',
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    'likeCount': 86,
    'commentCount': 12,
    'favoriteCount': 40,
    'isPinned': true,
    'status': 'ongoing',
    'tags': <String>['图书馆'],
    'canViewAuthorProfile': true,
  },
  <String, Object?>{
    'id': 'p2',
    'title': '示例：图书馆四楼靠窗那排插座修好了吗？',
    'content': '想问问有没有同学知道维修进度，期末周实在找不到位置。',
    'channel': '求助问答',
    'authorAlias': '安静的同学',
    'createdAt': DateTime.now()
        .subtract(const Duration(minutes: 12))
        .toIso8601String(),
    'likeCount': 12,
    'commentCount': 4,
    'favoriteCount': 3,
    'isAnonymous': true,
    'liked': true,
    'status': 'resolved',
    'tags': <String>['求助', '图书馆'],
  },
  <String, Object?>{
    'id': 'p3',
    'title': '示例：数学建模校赛组队，缺一位会写论文的同学',
    'content': '我们队目前两个人，一个负责建模、一个负责编程，还缺一位擅长写作和排版的同学。',
    'channel': '学习交流',
    'authorAlias': '林小舟',
    'authorId': 'u-lin',
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    'likeCount': 24,
    'commentCount': 6,
    'favoriteCount': 9,
    'favorited': true,
    'status': 'ongoing',
    'tags': <String>['组队', '竞赛'],
    'canViewAuthorProfile': true,
    'canFollowAuthor': true,
  },
  <String, Object?>{
    'id': 'p4',
    'title': '示例：仅自己可见的帖子',
    'content': '待审核时只有作者能看到这枚标记。',
    'channel': '吐槽日常',
    'authorAlias': '匿名同学',
    'createdAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    'isAnonymous': true,
    'isPrivate': true,
    'isOwnPost': true,
    'reviewStatus': 'pending',
    'status': 'closed',
  },
];
