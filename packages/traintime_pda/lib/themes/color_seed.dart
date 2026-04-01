import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Colors for the class information card.
const colorList = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
];

/// Bright mode select
const demoBlueModeMap = {
  0: ThemeMode.system,
  1: ThemeMode.light,
  2: ThemeMode.dark,
};

/// 与主App (lib/core/theme/shared_colors.dart) 品牌色对齐的 Teal 色系
/// Primary: #155E75  Accent: #E06C4E
sealed class TreeholeTealColor {
  static const FlexSchemeColor light = FlexSchemeColor(
    primary: Color(0xFF155E75),
    primaryContainer: Color(0xFFFFFFFF),
    primaryLightRef: Color(0xFF155E75),
    secondary: Color(0xFFE06C4E),
    secondaryContainer: Color(0xFFFFE0D6),
    secondaryLightRef: Color(0xFFE06C4E),
    tertiary: Color(0xFF00897B),
    tertiaryContainer: Color(0xFFFFFFFF),
    tertiaryLightRef: Color(0xFF00897B),
    appBarColor: Color(0xFFFFFFFF),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
  );

  static const FlexSchemeColor dark = FlexSchemeColor(
    primary: Color(0xFF4DD0E1),
    primaryContainer: Color(0xFF004D56),
    primaryLightRef: Color(0xFF155E75),
    secondary: Color(0xFFFF8A65),
    secondaryContainer: Color(0xFF7D2E1A),
    secondaryLightRef: Color(0xFFE06C4E),
    tertiary: Color(0xFF80CBC4),
    tertiaryContainer: Color(0xFF004D40),
    tertiaryLightRef: Color(0xFF00897B),
    appBarColor: Color(0xFF000000),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF93000A),
  );
}

const List<FlexSchemeColor> pdaColorScheme = [
  TreeholeTealColor.light,
  TreeholeTealColor.dark,
];

/// Colors for class information card which not in this week.
const uselessColor = Colors.grey;
