import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/zx_tokens.dart';
import '../../../core/theme/shared_colors.dart';
import 'mobile_colors.dart';

/// 主题配置数据类
class ThemeConfig {
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color seal;
  final Color background;
  final Color softBackground;
  final Color success;
  final Color warning;
  final Color error;

  const ThemeConfig({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.seal,
    required this.background,
    required this.softBackground,
    required this.success,
    required this.warning,
    required this.error,
  });
}

/// 移动端 iOS 风格主题
/// 遵循极简、优雅的设计理念
class MobileTheme {
  static const String interfaceFontFamily = AppTypography.chineseBody;
  static const List<String> interfaceFontFamilyFallback = [
    '华文宋体',
    'SimSun',
    '宋体',
  ];
  static const String brandFontFamily = AppTypography.chineseDisplay;
  static const List<String> brandFontFamilyFallback = [
    '华文中宋',
    'STSong',
    '华文宋体',
    'SimSun',
    '宋体',
  ];

  static const String quoteFontFamily = brandFontFamily;
  static const List<String> quoteFontFamilyFallback = brandFontFamilyFallback;

  // 共享状态色
  static const Color _success = Color(0xFF4F725E);
  static const Color _warning = Color(0xFF9A672A);
  static const Color _error = Color(0xFF97382F);

  static const Color success = _success;
  static const Color warning = _warning;
  static const Color error = _error;

  /// 配色数据保留历史键用于已发布版本迁移；新界面只开放主题目录中的键。
  static const Map<String, ThemeConfig> themes = {
    'zhushachi': ThemeConfig(
      primary: Color(0xFFA33A32),
      primaryDark: Color(0xFF7D2924),
      accent: Color(0xFFC46A50),
      seal: Color(0xFFA33A32),
      background: Color(0xFFF6F2EA),
      softBackground: Color(0xFFF0E5DF),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'yanzhihong': ThemeConfig(
      primary: Color(0xFFB8324A),
      primaryDark: Color(0xFF741B2D),
      accent: Color(0xFFD94F68),
      seal: Color(0xFFC4213B),
      background: Color(0xFFFBF1F3),
      softBackground: Color(0xFFF8DDE3),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'chitaonuan': ThemeConfig(
      primary: Color(0xFFB85B3E),
      primaryDark: Color(0xFF74301F),
      accent: Color(0xFFD97855),
      seal: Color(0xFFC94A2F),
      background: Color(0xFFFBF3EA),
      softBackground: Color(0xFFF5DFD1),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'zaonihong': ThemeConfig(
      primary: Color(0xFF8F2F2C),
      primaryDark: Color(0xFF5C1A18),
      accent: Color(0xFFB54A43),
      seal: Color(0xFFA92724),
      background: Color(0xFFF9F1EA),
      softBackground: Color(0xFFEFD8D2),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'xuanzhizhu': ThemeConfig(
      primary: Color(0xFFC43A2F),
      primaryDark: Color(0xFF7D211B),
      accent: Color(0xFFE15A48),
      seal: Color(0xFFD12B22),
      background: Color(0xFFFFF8EE),
      softBackground: Color(0xFFFBE4DC),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'zhuqing': ThemeConfig(
      primary: Color(0xFF426F52),
      primaryDark: Color(0xFF2D5139),
      accent: Color(0xFF71967B),
      seal: Color(0xFF426F52),
      background: Color(0xFFF3F7F2),
      softBackground: Color(0xFFE0EBDF),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'ouhezi': ThemeConfig(
      primary: Color(0xFF8B6F9E),
      primaryDark: Color(0xFF5B456D),
      accent: Color(0xFFAD93BF),
      seal: Color(0xFF765A8A),
      background: Color(0xFFF8F4FA),
      softBackground: Color(0xFFEBDFF1),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'xingrenhuang': ThemeConfig(
      primary: Color(0xFF94631F),
      primaryDark: Color(0xFF694513),
      accent: Color(0xFFC38D3B),
      seal: Color(0xFF94631F),
      background: Color(0xFFFBF6EA),
      softBackground: Color(0xFFF2E2BF),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'haiyanqing': ThemeConfig(
      primary: Color(0xFF5B9EA6),
      primaryDark: Color(0xFF346B72),
      accent: Color(0xFF84C2C8),
      seal: Color(0xFF478C94),
      background: Color(0xFFF1F8F8),
      softBackground: Color(0xFFDDEFF1),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'mohui': ThemeConfig(
      primary: Color(0xFF4F5552),
      primaryDark: Color(0xFF2B302E),
      accent: Color(0xFF747D78),
      seal: Color(0xFF3E4542),
      background: Color(0xFFF5F4F0),
      softBackground: Color(0xFFE7E5DF),
      success: _success,
      warning: _warning,
      error: _error,
    ),
    'mozhuxinye': ThemeConfig(
      primary: Color(0xFFAB3E36),
      primaryDark: Color(0xFF852E29),
      accent: Color(0xFFD87569),
      seal: Color(0xFFAB3E36),
      background: Color(0xFFFFFFFF),
      softBackground: Color(0xFFFAECE9),
      success: _success,
      warning: _warning,
      error: _error,
    ),
  };

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color primaryWithAlpha(BuildContext context, double alpha) =>
      primaryOf(context).withValues(alpha: alpha);

  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  /// 向后兼容
  static ThemeData get lightTheme =>
      getThemeData('zhushachi', const Locale('zh', 'CN'));

  /// The design-system theme (the same as web) for [themeKey] in
  /// [brightness], plus [MobileColors] from the same tokens so the pages
  /// not yet rebuilt follow the theme and dark mode too.
  static ThemeData getThemeData(
    String themeKey,
    Locale locale, {
    Brightness brightness = Brightness.light,
  }) {
    if (!AppColorThemes.isSupported(themeKey)) {
      throw ArgumentError.value(
        themeKey,
        'themeKey',
        'Unsupported color theme',
      );
    }
    final ThemeData base = AppTheme.designSystemFor(
      themeKey: themeKey,
      brightness: brightness,
    );
    final ZxTokens tokens = base.extension<ZxTokens>()!;
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        tokens,
        base.extension<EditorialColors>()!,
        MobileColors.fromPalette(tokens.palette),
      ],
    );
  }
}
