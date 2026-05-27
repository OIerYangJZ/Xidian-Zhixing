import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const String brandFontFamily = 'Source Han Serif SC';
  static const List<String> brandFontFamilyFallback = [
    'Songti SC',
    'Noto Serif CJK SC',
    'serif',
  ];

  static const String quoteFontFamily = brandFontFamily;
  static const List<String> quoteFontFamilyFallback = brandFontFamilyFallback;

  // 共享状态色
  static const Color _success = Color(0xFF4E7D66);
  static const Color _warning = Color(0xFFB7791F);
  static const Color _error = Color(0xFF9F1D1D);

  static const Color success = _success;
  static const Color warning = _warning;
  static const Color error = _error;

  /// 10 款主题配置
  static const Map<String, ThemeConfig> themes = {
    'zhushachi': ThemeConfig(
      primary: Color(0xFFB23A2E),
      primaryDark: Color(0xFF7A1E1A),
      accent: Color(0xFFD94A38),
      seal: Color(0xFFC7352A),
      background: Color(0xFFFAF4EA),
      softBackground: Color(0xFFF8E7E1),
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
      primary: Color(0xFF4F8A5F),
      primaryDark: Color(0xFF2F5C3D),
      accent: Color(0xFF78B985),
      seal: Color(0xFF3E744D),
      background: Color(0xFFF3F8F1),
      softBackground: Color(0xFFE0EFD8),
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
      primary: Color(0xFFC28A3A),
      primaryDark: Color(0xFF7A5422),
      accent: Color(0xFFDDAA5C),
      seal: Color(0xFFA9712B),
      background: Color(0xFFFCF7EC),
      softBackground: Color(0xFFF4E3C1),
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
  };

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color primaryWithAlpha(BuildContext context, double alpha) =>
      primaryOf(context).withValues(alpha: alpha);

  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  /// 向后兼容
  static ThemeData get lightTheme => getThemeData('zhushachi');

  /// 根据主题 key 动态构建 ThemeData
  static ThemeData getThemeData(String themeKey) {
    final config = themes[themeKey]!;
    final colors = MobileColors.fromThemeKey(themeKey);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: brandFontFamily,
      fontFamilyFallback: brandFontFamilyFallback,
      primaryColor: config.primary,
      scaffoldBackgroundColor: config.background,
      colorScheme: ColorScheme.light(
        primary: config.primary,
        secondary: config.accent,
        surface: Colors.white,
        error: config.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: colors.textPrimary,
        onError: Colors.white,
      ),

      // AppBar - iOS 大标题风格
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: config.background,
        foregroundColor: config.primaryDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: config.primaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: brandFontFamily,
          fontFamilyFallback: brandFontFamilyFallback,
        ),
        iconTheme: IconThemeData(color: config.primary),
      ),

      // 底部导航栏 - CupertinoTabBar 风格
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: config.primary,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),

      // 卡片样式 - 圆角卡片，轻阴影
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      // 输入框样式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.error),
        ),
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 15),
      ),

      // 按钮样式
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: config.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: config.primary,
          side: BorderSide(color: config.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // TabBar 样式
      tabBarTheme: TabBarThemeData(
        labelColor: config.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: config.primary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chip 样式 - 无圆角、无边框
      chipTheme: ChipThemeData(
        backgroundColor: config.background,
        selectedColor: config.primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: BorderSide.none,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 0.5,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF3C3C43).withValues(alpha: 0.9),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
          fontFamily: brandFontFamily,
          fontFamilyFallback: brandFontFamilyFallback,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
          fontFamily: brandFontFamily,
          fontFamilyFallback: brandFontFamilyFallback,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
          fontFamily: brandFontFamily,
          fontFamilyFallback: brandFontFamilyFallback,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
          fontFamily: brandFontFamily,
          fontFamilyFallback: brandFontFamilyFallback,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.normal,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: colors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: colors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.textTertiary,
        ),
      ),

      // MobileColors 扩展 - 用于 MobileColors.of(context)
      extensions: [colors],
    );
  }
}
