import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

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
/// fonts, and production cannot fetch fallbacks from Google Fonts, so the web
/// body family has to be bundled; until one is, web keeps the bundled serif.
abstract final class ZxFonts {
  /// Brand, page titles, empty states and quotes (a Songti subset).
  static const String display = 'STZhongsong';
  static const List<String> displayFallback = <String>[
    'STSong',
    'Songti SC',
    'Noto Serif CJK SC',
  ];

  /// Bundled web body family; null means "platform default".
  static const String? _webBody = 'STSong';

  static String? get body => kIsWeb ? _webBody : null;

  static const List<String> bodyFallback = <String>[
    'PingFang SC',
    'HarmonyOS Sans SC',
    'MiSans',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
  ];
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
