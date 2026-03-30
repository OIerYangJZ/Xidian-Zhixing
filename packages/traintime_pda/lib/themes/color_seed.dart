// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:watermeter/themes/green.dart';
import 'package:watermeter/themes/orange.dart';

/// 与主App SharedColors.primary (#155E75) 对齐的品牌色（浅色）
FlexSchemeColor get pdaTealLight => FlexSchemeColor(
  primary: const Color(0xFF155E75),
  primaryContainer: const Color(0xFFB2EBF2),
  secondary: const Color(0xFFE06C4E),
  secondaryContainer: const Color(0xFFFFCCBC),
  tertiary: const Color(0xFF00796B),
  tertiaryContainer: const Color(0xFFB2DFDB),
  appBarColor: const Color(0xFFEAF4FA),
);

/// 与主App SharedColors 对齐的品牌色（深色）
FlexSchemeColor get pdaTealDark => FlexSchemeColor(
  primary: const Color(0xFF4DD0E1),
  primaryContainer: const Color(0xFF006064),
  secondary: const Color(0xFFFF8A65),
  secondaryContainer: const Color(0xFFBF360C),
  tertiary: const Color(0xFF80CBC4),
  tertiaryContainer: const Color(0xFF004D40),
  appBarColor: const Color(0xFF1C1C1E),
);

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

List<FlexSchemeColor> pdaColorScheme = [
  pdaTealLight,
  pdaTealDark,
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
  indigo('default', 0),
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
