import 'package:flutter/material.dart';

/// 跨端共享的品牌颜色常量
/// 两端主题均引用此文件，确保品牌色彩一致
class SharedColors {
  SharedColors._();

  static const Color primary = Color(0xFFB23A2E); // brand.primary
  static const Color deep = Color(0xFF7A1E1A);    // brand.deep
  static const Color bright = Color(0xFFD94A38);  // brand.bright
  static const Color seal = Color(0xFFC7352A);    // brand.seal
  static const Color background = Color(0xFFFAF4EA); // background.paper
  static const Color softRed = Color(0xFFF8E7E1); // background.softRed
  static const Color textPrimary = Color(0xFF2D2522); // text.primary
  static const Color textSecondary = Color(0xFF7B6F6A); // text.secondary
  static const Color divider = Color(0xFFE8DAD2); // border.default
  static const Color success = Color(0xFF4E7D66); // state.success
  static const Color warning = Color(0xFFB7791F); // state.warning
  static const Color danger = Color(0xFF9F1D1D); // state.danger

  static const Color accent = Color(0xFFD94A38);
}
