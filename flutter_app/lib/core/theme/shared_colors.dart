import 'package:flutter/material.dart';

/// A complete visual preset. Adding a future product theme means adding one
/// preset here, rather than introducing colours in pages or components.
@immutable
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String id;
  final String label;
  final EditorialColors light;
  final EditorialColors dark;
}

class AppThemePresets {
  AppThemePresets._();

  /// Product default. White is the canvas; ink, vermilion and gold carry the
  /// brand identity in purposeful, limited places.
  static final AppThemePreset inkVermilion = AppThemePreset(
    id: 'ink_vermilion',
    label: '墨朱金',
    light: _inkVermilionLight,
    dark: _inkVermilionDark,
  );

  static final List<AppThemePreset> all = <AppThemePreset>[inkVermilion];

  static AppThemePreset byId(String id) => all.firstWhere(
    (AppThemePreset preset) => preset.id == id,
    orElse: () => inkVermilion,
  );
}

const EditorialColors _inkVermilionLight = EditorialColors(
  page: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceHover: Color(0xFFF4F4F1),
  ink: Color(0xFF191917),
  mutedInk: Color(0xFF6F706B),
  faintInk: Color(0xFFA0A19B),
  line: Color(0xFFE8E8E4),
  primary: Color(0xFFAB3E36),
  primaryActive: Color(0xFF852E29),
  coral: Color(0xFFD87569),
  apricot: Color(0xFFE6B75D),
  primarySubtle: Color(0xFFFAECE9),
  infoSubtle: Color(0xFFEEF3F4),
  darkPanel: Color(0xFF191917),
  onDarkPanel: Color(0xFFFFFEFB),
  railMuted: Color(0xFFB9BAB3),
  railSelected: Color(0xFF302E2B),
  success: Color(0xFF387157),
  warning: Color(0xFF9A681E),
  danger: Color(0xFFAF3E36),
  info: Color(0xFF356B80),
);

const EditorialColors _inkVermilionDark = EditorialColors(
  page: Color(0xFF151513),
  surface: Color(0xFF1D1D1B),
  surfaceRaised: Color(0xFF252522),
  surfaceHover: Color(0xFF302F2C),
  ink: Color(0xFFF5F5F0),
  mutedInk: Color(0xFFB7B8B1),
  faintInk: Color(0xFF85867F),
  line: Color(0xFF343430),
  primary: Color(0xFFE37D73),
  primaryActive: Color(0xFFF0A096),
  coral: Color(0xFFF09A8E),
  apricot: Color(0xFFE9C26E),
  primarySubtle: Color(0xFF432B28),
  infoSubtle: Color(0xFF243337),
  darkPanel: Color(0xFF0F0F0E),
  onDarkPanel: Color(0xFFF8F8F3),
  railMuted: Color(0xFFAFAFA8),
  railSelected: Color(0xFF302F2C),
  success: Color(0xFF83B894),
  warning: Color(0xFFE8BD6B),
  danger: Color(0xFFE98C84),
  info: Color(0xFF8CBBC6),
);

/// Semantic colour tokens consumed by Flutter Web. There are deliberately no
/// product colour constants in feature code.
@immutable
class EditorialColors extends ThemeExtension<EditorialColors> {
  const EditorialColors({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.ink,
    required this.mutedInk,
    required this.faintInk,
    required this.line,
    required this.primary,
    required this.primaryActive,
    required this.coral,
    required this.apricot,
    required this.primarySubtle,
    required this.infoSubtle,
    required this.darkPanel,
    required this.onDarkPanel,
    required this.railMuted,
    required this.railSelected,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceHover;
  final Color ink;
  final Color mutedInk;
  final Color faintInk;
  final Color line;
  final Color primary;
  final Color primaryActive;
  final Color coral;
  final Color apricot;
  final Color primarySubtle;
  final Color infoSubtle;
  final Color darkPanel;
  final Color onDarkPanel;
  final Color railMuted;
  final Color railSelected;
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
    Color? surfaceRaised,
    Color? surfaceHover,
    Color? ink,
    Color? mutedInk,
    Color? faintInk,
    Color? line,
    Color? primary,
    Color? primaryActive,
    Color? coral,
    Color? apricot,
    Color? primarySubtle,
    Color? infoSubtle,
    Color? darkPanel,
    Color? onDarkPanel,
    Color? railMuted,
    Color? railSelected,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) => EditorialColors(
    page: page ?? this.page,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceHover: surfaceHover ?? this.surfaceHover,
    ink: ink ?? this.ink,
    mutedInk: mutedInk ?? this.mutedInk,
    faintInk: faintInk ?? this.faintInk,
    line: line ?? this.line,
    primary: primary ?? this.primary,
    primaryActive: primaryActive ?? this.primaryActive,
    coral: coral ?? this.coral,
    apricot: apricot ?? this.apricot,
    primarySubtle: primarySubtle ?? this.primarySubtle,
    infoSubtle: infoSubtle ?? this.infoSubtle,
    darkPanel: darkPanel ?? this.darkPanel,
    onDarkPanel: onDarkPanel ?? this.onDarkPanel,
    railMuted: railMuted ?? this.railMuted,
    railSelected: railSelected ?? this.railSelected,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
  );

  @override
  EditorialColors lerp(covariant EditorialColors? other, double t) {
    if (other == null) {
      return this;
    }
    return EditorialColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      faintInk: Color.lerp(faintInk, other.faintInk, t)!,
      line: Color.lerp(line, other.line, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryActive: Color.lerp(primaryActive, other.primaryActive, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      apricot: Color.lerp(apricot, other.apricot, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      darkPanel: Color.lerp(darkPanel, other.darkPanel, t)!,
      onDarkPanel: Color.lerp(onDarkPanel, other.onDarkPanel, t)!,
      railMuted: Color.lerp(railMuted, other.railMuted, t)!,
      railSelected: Color.lerp(railSelected, other.railSelected, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Temporary mobile compatibility. Flutter Web must obtain tokens from
/// [EditorialColors.of] so runtime theme changes reach every component.
@Deprecated('Use EditorialColors.of(context) in Flutter Web.')
class SharedColors {
  SharedColors._();

  static final EditorialColors light = _inkVermilionLight;
  static final EditorialColors dark = _inkVermilionDark;
  static final Color primary = light.primary;
  static final Color deep = light.primaryActive;
  static final Color bright = light.coral;
  static final Color seal = light.primary;
  static final Color accent = light.info;
  static final Color background = light.page;
  static final Color surface = light.surface;
  static final Color softRed = light.primarySubtle;
  static final Color softBlue = light.infoSubtle;
  static final Color textPrimary = light.ink;
  static final Color textSecondary = light.mutedInk;
  static final Color divider = light.line;
  static final Color success = light.success;
  static final Color warning = light.warning;
  static final Color danger = light.danger;
  static final Color adminPrimary = Color(0xFF244A5A);
  static final Color adminAccent = Color(0xFFB57A28);
}
