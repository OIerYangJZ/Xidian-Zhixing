import 'package:flutter/material.dart';

/// 跨端共享的品牌颜色常量
/// 两端主题均引用此文件，确保品牌色彩一致
class SharedColors {
  SharedColors._();

  static const EditorialColors light = EditorialColors(
    page: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFEFA),
    ink: Color(0xFF181816),
    mutedInk: Color(0xFF66635D),
    line: Color(0xFFD8D5CC),
    primary: Color(0xFFA43B32),
    primaryActive: Color(0xFF7E2924),
    coral: Color(0xFFD9775F),
    apricot: Color(0xFFE8B65D),
    primarySubtle: Color(0xFFF1E5DF),
    infoSubtle: Color(0xFFE8EEEF),
    darkPanel: Color(0xFF1E1E1B),
    onDarkPanel: Color(0xFFF7F6F2),
    success: Color(0xFF4F725E),
    warning: Color(0xFF966323),
    danger: Color(0xFF97382F),
    info: Color(0xFF4E7180),
  );

  static const EditorialColors dark = EditorialColors(
    page: Color(0xFF171714),
    surface: Color(0xFF20201C),
    ink: Color(0xFFF4F1E8),
    mutedInk: Color(0xFFBBB6AA),
    line: Color(0xFF45443D),
    primary: Color(0xFFE08075),
    primaryActive: Color(0xFFF09A8E),
    coral: Color(0xFFE89478),
    apricot: Color(0xFFEBC474),
    primarySubtle: Color(0xFF3C2824),
    infoSubtle: Color(0xFF263336),
    darkPanel: Color(0xFFF1EDE4),
    onDarkPanel: Color(0xFF1A1A17),
    success: Color(0xFF8CB79B),
    warning: Color(0xFFE2B46E),
    danger: Color(0xFFE58A80),
    info: Color(0xFF8DB8C2),
  );

  // Compatibility aliases. New UI code should read EditorialColors.of(context).
  static const Color primary = Color(0xFFA43B32);
  static const Color deep = Color(0xFF7E2924);
  static const Color bright = Color(0xFFD9775F);
  static const Color seal = primary;
  static const Color accent = Color(0xFF4E7180);
  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Color(0xFFFFFEFA);
  static const Color softRed = Color(0xFFF1E5DF);
  static const Color softBlue = Color(0xFFE8EEEF);
  static const Color textPrimary = Color(0xFF181816);
  static const Color textSecondary = Color(0xFF66635D);
  static const Color divider = Color(0xFFD8D5CC);
  static const Color success = Color(0xFF4F725E);
  static const Color warning = Color(0xFF966323);
  static const Color danger = Color(0xFF97382F);
  static const Color adminPrimary = Color(0xFF244A5A);
  static const Color adminAccent = Color(0xFFB57A28);
}

@immutable
class EditorialColors extends ThemeExtension<EditorialColors> {
  const EditorialColors({
    required this.page,
    required this.surface,
    required this.ink,
    required this.mutedInk,
    required this.line,
    required this.primary,
    required this.primaryActive,
    required this.coral,
    required this.apricot,
    required this.primarySubtle,
    required this.infoSubtle,
    required this.darkPanel,
    required this.onDarkPanel,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color page;
  final Color surface;
  final Color ink;
  final Color mutedInk;
  final Color line;
  final Color primary;
  final Color primaryActive;
  final Color coral;
  final Color apricot;
  final Color primarySubtle;
  final Color infoSubtle;
  final Color darkPanel;
  final Color onDarkPanel;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static EditorialColors of(BuildContext context) =>
      Theme.of(context).extension<EditorialColors>()!;

  @override
  EditorialColors copyWith({
    Color? page,
    Color? surface,
    Color? ink,
    Color? mutedInk,
    Color? line,
    Color? primary,
    Color? primaryActive,
    Color? coral,
    Color? apricot,
    Color? primarySubtle,
    Color? infoSubtle,
    Color? darkPanel,
    Color? onDarkPanel,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return EditorialColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      mutedInk: mutedInk ?? this.mutedInk,
      line: line ?? this.line,
      primary: primary ?? this.primary,
      primaryActive: primaryActive ?? this.primaryActive,
      coral: coral ?? this.coral,
      apricot: apricot ?? this.apricot,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      darkPanel: darkPanel ?? this.darkPanel,
      onDarkPanel: onDarkPanel ?? this.onDarkPanel,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  EditorialColors lerp(
    covariant ThemeExtension<EditorialColors>? other,
    double t,
  ) {
    if (other is! EditorialColors) {
      return this;
    }
    return EditorialColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      line: Color.lerp(line, other.line, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryActive: Color.lerp(primaryActive, other.primaryActive, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      apricot: Color.lerp(apricot, other.apricot, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      darkPanel: Color.lerp(darkPanel, other.darkPanel, t)!,
      onDarkPanel: Color.lerp(onDarkPanel, other.onDarkPanel, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
