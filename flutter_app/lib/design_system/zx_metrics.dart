import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Corner radii from the design system (§05). Everything is one step rounder
/// than the previous UI.
abstract final class ZxRadius {
  static const double badge = 6;
  static const double smallButton = 11;
  static const double button = 14;
  static const double card = 18;
  static const double sheet = 24;
  static const double pill = 999;

  static const BorderRadius badgeAll = BorderRadius.all(Radius.circular(badge));
  static const BorderRadius smallButtonAll = BorderRadius.all(
    Radius.circular(smallButton),
  );
  static const BorderRadius buttonAll = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetAll = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Sizes that recur across components.
abstract final class ZxSize {
  static const double iconButton = 44;
  static const double fab = 56;
  static const double minTouchTarget = 44;
}

/// Font families. Body text uses the platform sans-serif on Android and the
/// mini program. Flutter Web draws with CanvasKit and cannot reach system
/// fonts, and production cannot fetch fallbacks from Google Fonts, so web
/// bundles its own: ZxSans, a Noto Sans SC subset (scripts/build_web_font.py).
abstract final class ZxFonts {
  /// Brand, page titles, empty states, quotes and avatar initials: a Songti
  /// subset with ZxSans's characters (scripts/build_songti_fonts.py).
  static const String display = 'STZhongsong';
  static const List<String> displayFallback = <String>[
    'STSong',
    'Songti SC',
    'Noto Serif CJK SC',
  ];

  /// Null means the platform default (Android, and anything not web).
  static String? get body => debugWebFonts || kIsWeb ? 'ZxSans' : null;

  /// Screen captures in tests set this to render with the web font stack.
  /// Must be set before [ZxType] is first read, which caches its styles.
  @visibleForTesting
  static bool debugWebFonts = false;

  static const List<String> _platformSans = <String>[
    'PingFang SC',
    'HarmonyOS Sans SC',
    'MiSans',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
  ];

  /// On web, characters outside the ZxSans subset (rare hanzi in names and
  /// user content) fall back to STSong, never to a download from Google.
  static List<String> get bodyFallback =>
      debugWebFonts || kIsWeb ? const <String>['STSong'] : _platformSans;

  static Future<void>? _deferred;

  /// Where the web build serves the font. From the base href, not the page:
  /// a share link opens on /p/<id>, where 'fonts/…' would resolve to
  /// /p/fonts/…. The public build uses base href '/'; the admin console
  /// published under /admin/ passes WEB_BASE_HREF=/admin/ to match its
  /// --base-href (scripts/build_web_admin.sh).
  static const String _webBaseHref = String.fromEnvironment(
    'WEB_BASE_HREF',
    defaultValue: '/',
  );
  static const String webRareFontPath = '${_webBaseHref}fonts/STSong-Rare.ttf';

  @visibleForTesting
  static Future<ByteData> Function(Uri url) debugFetchFont = _fetchWebFont;

  @visibleForTesting
  static void debugResetDeferred() => _deferred = null;

  /// Registers STSong (only the characters ZxSans lacks) on web. It is not a
  /// manifest font because the engine downloads those before the first
  /// frame; text laid out before it arrives is laid out again once it does.
  /// Nor is it an asset: it is served from web/fonts/, so the APK does not
  /// carry it. Android draws rare characters with the system fonts instead.
  ///
  /// A failed download is not remembered, so the next theme build tries
  /// again instead of leaving rare characters as tofu for the session.
  static Future<void> loadDeferred() =>
      kIsWeb ? loadRareFont() : Future<void>.value();

  /// [loadDeferred] without the platform check, for tests.
  @visibleForTesting
  static Future<void> loadRareFont() {
    return _deferred ??=
        (FontLoader('STSong')
              ..addFont(debugFetchFont(Uri.base.resolve(webRareFontPath))))
            .load()
            .catchError((Object error) {
              _deferred = null;
              debugPrint('STSong-Rare not loaded: $error');
            });
  }

  static Future<ByteData> _fetchWebFont(Uri url) async {
    final http.Response response = await http.get(url);
    if (response.statusCode != 200) {
      throw StateError('$url: HTTP ${response.statusCode}');
    }
    return ByteData.sublistView(response.bodyBytes);
  }
}

/// Type scale (§05): size / line height / weight. The design's 650 weight
/// maps to w600, the closest Flutter weight.
abstract final class ZxType {
  static TextStyle _display(double size, double height) => TextStyle(
    fontFamily: ZxFonts.display,
    fontFamilyFallback: ZxFonts.displayFallback,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.w600,
  );

  static TextStyle _body(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: ZxFonts.body,
        fontFamilyFallback: ZxFonts.bodyFallback,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
      );

  static final TextStyle display = _display(34, 42);
  static final TextStyle headline = _display(26, 34);
  static final TextStyle titleLarge = _body(22, 30, FontWeight.w600);
  static final TextStyle title = _body(17, 25, FontWeight.w600);
  static final TextStyle body = _body(15, 23, FontWeight.w400);
  static final TextStyle label = _body(14, 20, FontWeight.w600);
  static final TextStyle caption = _body(12, 16, FontWeight.w400);
  static final TextStyle micro = _body(11, 14, FontWeight.w600);
}

/// Motion (§03).
abstract final class ZxMotion {
  static const Duration likePop = Duration(milliseconds: 280);
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Duration standard = Duration(milliseconds: 200);
}
