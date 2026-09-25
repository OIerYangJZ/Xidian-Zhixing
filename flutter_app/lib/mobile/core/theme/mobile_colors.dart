import 'package:flutter/material.dart';

import '../../../design_system/zx_tokens.dart';

/// 移动端主题颜色扩展（ThemeExtension）
/// 支持跨端主题目录中的自定义配色，通过 MobileColors.of(context) 在 build() 中获取当前主题颜色。
///
/// 用法：
/// ```dart
/// final colors = MobileColors.of(context);
/// Container(color: colors.background)
/// Text('hello', style: TextStyle(color: colors.textPrimary))
/// ```
class MobileColors extends ThemeExtension<MobileColors> {
  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  // Custom theme colors
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color seal;
  final Color softBackground;
  final Color success;
  final Color warning;
  final Color error;

  const MobileColors({
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.seal,
    required this.softBackground,
    required this.success,
    required this.warning,
    required this.error,
  });

  // Shared state colors
  static const Color _success = Color(0xFF4F725E);
  static const Color _warning = Color(0xFF9A672A);
  static const Color _error = Color(0xFF97382F);

  /// 朱砂赤配色（默认）
  static const light = MobileColors(
    background: Color(0xFFF6F2EA),
    surface: Color(0xFFFFFCF7),
    cardBackground: Color(0xFFFFFCF7),
    textPrimary: Color(0xFF292522),
    textSecondary: Color(0xFF716A64),
    textTertiary: Color(0xFF978F88),
    divider: Color(0xFFDED6CB),
    primary: Color(0xFFA33A32),
    primaryDark: Color(0xFF7D2924),
    accent: Color(0xFFC46A50),
    seal: Color(0xFFA33A32),
    softBackground: Color(0xFFF0E5DF),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _zhushachi = light;

  static const _yanzhihong = MobileColors(
    background: Color(0xFFFBF1F3),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2E2427),
    textSecondary: Color(0xFF7A686D),
    textTertiary: Color(0xFFB2A2A7),
    divider: Color(0xFFE8D4DA),
    primary: Color(0xFFB8324A),
    primaryDark: Color(0xFF741B2D),
    accent: Color(0xFFD94F68),
    seal: Color(0xFFC4213B),
    softBackground: Color(0xFFF8DDE3),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _chitaonuan = MobileColors(
    background: Color(0xFFFBF3EA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2F2823),
    textSecondary: Color(0xFF7C6D64),
    textTertiary: Color(0xFFB4A69E),
    divider: Color(0xFFE7D7CA),
    primary: Color(0xFFB85B3E),
    primaryDark: Color(0xFF74301F),
    accent: Color(0xFFD97855),
    seal: Color(0xFFC94A2F),
    softBackground: Color(0xFFF5DFD1),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _zaonihong = MobileColors(
    background: Color(0xFFF9F1EA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2B2422),
    textSecondary: Color(0xFF756B67),
    textTertiary: Color(0xFFA89C97),
    divider: Color(0xFFE1D2CB),
    primary: Color(0xFF8F2F2C),
    primaryDark: Color(0xFF5C1A18),
    accent: Color(0xFFB54A43),
    seal: Color(0xFFA92724),
    softBackground: Color(0xFFEFD8D2),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _xuanzhizhu = MobileColors(
    background: Color(0xFFFFF8EE),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2F2520),
    textSecondary: Color(0xFF7E7068),
    textTertiary: Color(0xFFB8A9A0),
    divider: Color(0xFFEAD9CF),
    primary: Color(0xFFC43A2F),
    primaryDark: Color(0xFF7D211B),
    accent: Color(0xFFE15A48),
    seal: Color(0xFFD12B22),
    softBackground: Color(0xFFFBE4DC),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _zhuqing = MobileColors(
    background: Color(0xFFF3F7F2),
    surface: Color(0xFFFFFEF9),
    cardBackground: Color(0xFFFFFEF9),
    textPrimary: Color(0xFF202A23),
    textSecondary: Color(0xFF657168),
    textTertiary: Color(0xFF929E94),
    divider: Color(0xFFD3DED2),
    primary: Color(0xFF426F52),
    primaryDark: Color(0xFF2D5139),
    accent: Color(0xFF71967B),
    seal: Color(0xFF426F52),
    softBackground: Color(0xFFE0EBDF),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _ouhezi = MobileColors(
    background: Color(0xFFF8F4FA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2D2632),
    textSecondary: Color(0xFF746A7A),
    textTertiary: Color(0xFFA69BAE),
    divider: Color(0xFFDED2E4),
    primary: Color(0xFF8B6F9E),
    primaryDark: Color(0xFF5B456D),
    accent: Color(0xFFAD93BF),
    seal: Color(0xFF765A8A),
    softBackground: Color(0xFFEBDFF1),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _xingrenhuang = MobileColors(
    background: Color(0xFFFBF6EA),
    surface: Color(0xFFFFFEF8),
    cardBackground: Color(0xFFFFFEF8),
    textPrimary: Color(0xFF30281E),
    textSecondary: Color(0xFF766A5B),
    textTertiary: Color(0xFFA99C89),
    divider: Color(0xFFE4D5B9),
    primary: Color(0xFF94631F),
    primaryDark: Color(0xFF694513),
    accent: Color(0xFFC38D3B),
    seal: Color(0xFF94631F),
    softBackground: Color(0xFFF2E2BF),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _haiyanqing = MobileColors(
    background: Color(0xFFF1F8F8),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF223032),
    textSecondary: Color(0xFF647678),
    textTertiary: Color(0xFF9AAFB2),
    divider: Color(0xFFD0E2E4),
    primary: Color(0xFF5B9EA6),
    primaryDark: Color(0xFF346B72),
    accent: Color(0xFF84C2C8),
    seal: Color(0xFF478C94),
    softBackground: Color(0xFFDDEFF1),
    success: _success,
    warning: _warning,
    error: _error,
  );

  static const _mohui = MobileColors(
    background: Color(0xFFF5F4F0),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF242523),
    textSecondary: Color(0xFF6E706B),
    textTertiary: Color(0xFFA2A5A0),
    divider: Color(0xFFDAD8D1),
    primary: Color(0xFF4F5552),
    primaryDark: Color(0xFF2B302E),
    accent: Color(0xFF747D78),
    seal: Color(0xFF3E4542),
    softBackground: Color(0xFFE7E5DF),
    success: _success,
    warning: _warning,
    error: _error,
  );

  /// 墨朱·新页：与 Web 的 SharedColors.discussionLight 同一组色值。
  static const _mozhuxinye = MobileColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF191917),
    textSecondary: Color(0xFF6F706B),
    textTertiary: Color(0xFFA2A39E),
    divider: Color(0xFFE8E8E4),
    primary: Color(0xFFAB3E36),
    primaryDark: Color(0xFF852E29),
    accent: Color(0xFFD87569),
    seal: Color(0xFFAB3E36),
    softBackground: Color(0xFFFAECE9),
    success: _success,
    warning: _warning,
    error: _error,
  );

  /// The design tokens for [key] and [brightness], in the legacy shape the
  /// Android pages read. Every theme and dark mode go through here.
  static MobileColors fromPalette(ZxPalette p) => MobileColors(
    background: p.bg,
    surface: p.surface,
    cardBackground: p.surface,
    textPrimary: p.text,
    textSecondary: p.text2,
    textTertiary: p.text3,
    divider: p.line,
    primary: p.primary,
    primaryDark: p.primaryPressed,
    accent: p.coral,
    seal: p.seal,
    softBackground: p.primarySoft,
    success: p.success,
    warning: p.warning,
    error: p.danger,
  );

  /// Pre-token palettes, kept for the retired theme keys only.
  static MobileColors legacyFromThemeKey(String key) {
    return switch (key) {
      'zhushachi' => _zhushachi,
      'yanzhihong' => _yanzhihong,
      'chitaonuan' => _chitaonuan,
      'zaonihong' => _zaonihong,
      'xuanzhizhu' => _xuanzhizhu,
      'zhuqing' => _zhuqing,
      'ouhezi' => _ouhezi,
      'xingrenhuang' => _xingrenhuang,
      'haiyanqing' => _haiyanqing,
      'mohui' => _mohui,
      'mozhuxinye' => _mozhuxinye,
      _ => _zhushachi,
    };
  }

  /// The light palette of [key], from the tokens.
  static MobileColors fromThemeKey(String key) =>
      fromPalette(zxPaletteFor(key, Brightness.light));

  /// 从当前 BuildContext 读取主题颜色
  static MobileColors of(BuildContext context) =>
      Theme.of(context).extension<MobileColors>()!;

  @override
  MobileColors copyWith({
    Color? background,
    Color? surface,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? seal,
    Color? softBackground,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return MobileColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      seal: seal ?? this.seal,
      softBackground: softBackground ?? this.softBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  MobileColors lerp(ThemeExtension<MobileColors>? other, double t) {
    if (other is! MobileColors) return this;
    return MobileColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      seal: Color.lerp(seal, other.seal, t)!,
      softBackground: Color.lerp(softBackground, other.softBackground, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
