import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:watermeter/themes/default.dart';
import 'package:watermeter/themes/green.dart';
import 'package:watermeter/themes/orange.dart';

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
    appBarColor: Color(0xFF1C1C1E),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF93000A),
  );
}

List<FlexSchemeColor> pdaColorScheme = [
  TreeholeTealColor.light,   // 与主App品牌色对齐 (#155E75)
  TreeholeTealColor.dark,
  FlexScheme.blue.colors(Brightness.light),
  FlexScheme.blue.colors(Brightness.dark),
  FlexScheme.deepPurple.colors(Brightness.light),
  FlexScheme.deepPurple.colors(Brightness.dark),
  GreenColor.light,
  GreenColor.dark,
  OrangeColor.light,
  OrangeColor.dark,
  FlexScheme.pinkM3.colors(Brightness.light),
  FlexScheme.pinkM3.colors(Brightness.dark),
];

enum ColorSeed {
  teal('teal', 0),         // 新增，与主App对齐，默认选中
  blue('blue', 1),
  deepPurple('deepPurple', 2),
  green('green', 3),
  orange('orange', 4),
  pink('pink', 5);

  const ColorSeed(this.label, this.colorOffset);
  final String label;
  final int colorOffset;
}

/// Colors for class information card which not in this week.
const uselessColor = Colors.grey;
