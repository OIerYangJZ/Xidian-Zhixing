import 'package:flutter/material.dart';

/// 跨端共享的品牌颜色常量
/// 两端主题均引用此文件，确保品牌色彩一致
class SharedColors {
  SharedColors._();

  // 朱赤白 · 印信
  static const Color primary = Color(0xFFA33A32); // brand.primary
  static const Color deep = Color(0xFF7D2924); // brand.active
  static const Color bright = Color(0xFFC46A50); // brand.accent
  static const Color seal = Color(0xFFA33A32); // brand.seal
  static const Color accent = Color(0xFF4E7180); // semantic.info

  static const Color background = Color(0xFFF6F2EA); // background.page
  static const Color surface = Color(0xFFFFFCF7); // background.surface
  static const Color softRed = Color(0xFFF0E5DF); // background.brandSubtle
  static const Color softBlue = Color(0xFFE7EEF0); // background.infoSubtle
  static const Color textPrimary = Color(0xFF292522); // text.primary
  static const Color textSecondary = Color(0xFF716A64); // text.secondary
  static const Color divider = Color(0xFFDED6CB); // border.default
  static const Color success = Color(0xFF4F725E); // state.success
  static const Color warning = Color(0xFF9A672A); // state.warning
  static const Color danger = Color(0xFF97382F); // state.danger

  static const Color adminPrimary = Color(0xFF244A5A);
  static const Color adminAccent = Color(0xFFB57A28);
}
