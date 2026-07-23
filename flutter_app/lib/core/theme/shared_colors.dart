import 'package:flutter/material.dart';

/// 跨端共享的品牌颜色常量
/// 两端主题均引用此文件，确保品牌色彩一致
class SharedColors {
  SharedColors._();

  static const Color primary = Color(0xFF922F2F); // brand.primary
  static const Color deep = Color(0xFF641F24); // brand.deep
  static const Color bright = Color(0xFFB54A43); // brand.bright
  static const Color seal = Color(0xFF922F2F); // brand.seal
  static const Color accent = Color(0xFF2F6674); // brand.accent

  static const Color background = Color(0xFFF6F6F2); // background.canvas
  static const Color surface = Color(0xFFFFFFFF); // background.surface
  static const Color softRed = Color(0xFFF8ECE9); // background.softRed
  static const Color softBlue = Color(0xFFEAF2F3); // background.softBlue
  static const Color textPrimary = Color(0xFF252323); // text.primary
  static const Color textSecondary = Color(0xFF6F6A68); // text.secondary
  static const Color divider = Color(0xFFE6E3DE); // border.default
  static const Color success = Color(0xFF2D7255); // state.success
  static const Color warning = Color(0xFF986615); // state.warning
  static const Color danger = Color(0xFFAA2C2C); // state.danger

  static const Color adminPrimary = Color(0xFF244A5A);
  static const Color adminAccent = Color(0xFFB57A28);
}
