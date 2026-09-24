import 'package:flutter/material.dart';

import 'zx_palette.g.dart';

export 'zx_palette.g.dart';

/// Looks up a theme by key, falling back to the default so a stale stored
/// preference never throws.
ZxThemeInfo zxThemeFor(String key) => zxThemes.firstWhere(
  (ZxThemeInfo theme) => theme.key == key,
  orElse: () => zxThemes.firstWhere(
    (ZxThemeInfo theme) => theme.key == zxDefaultThemeKey,
  ),
);

ZxPalette zxPaletteFor(String key, Brightness brightness) {
  final ZxThemeInfo theme = zxThemeFor(key);
  return brightness == Brightness.dark ? theme.dark : theme.light;
}

/// Design tokens carried on the [ThemeData], so every widget reads colors by
/// role (`ZxTokens.of(context).text2`) and never by value.
@immutable
class ZxTokens extends ThemeExtension<ZxTokens> {
  const ZxTokens(this.palette);

  final ZxPalette palette;

  static ZxTokens of(BuildContext context) =>
      Theme.of(context).extension<ZxTokens>() ??
      ZxTokens(zxPaletteFor(zxDefaultThemeKey, Theme.of(context).brightness));

  Color get bg => palette.bg;
  Color get bgSunk => palette.bgSunk;
  Color get surface => palette.surface;
  Color get raised => palette.raised;
  Color get glass => palette.glass;
  Color get line => palette.line;
  Color get lineStrong => palette.lineStrong;
  Color get text => palette.text;
  Color get text2 => palette.text2;
  Color get text3 => palette.text3;
  Color get primary => palette.primary;
  Color get primaryPressed => palette.primaryPressed;
  Color get onPrimary => palette.onPrimary;
  Color get primarySoft => palette.primarySoft;
  Color get primaryGlow => palette.primaryGlow;
  Color get seal => palette.seal;
  Color get sealSoft => palette.sealSoft;
  Color get accent => palette.accent;
  Color get accentSoft => palette.accentSoft;
  Color get accentInk => palette.accentInk;
  Color get coral => palette.coral;
  Color get success => palette.success;
  Color get successSoft => palette.successSoft;
  Color get warning => palette.warning;
  Color get warningSoft => palette.warningSoft;
  Color get danger => palette.danger;
  Color get dangerSoft => palette.dangerSoft;
  Color get onDanger => palette.onDanger;
  Color get info => palette.info;
  Color get infoSoft => palette.infoSoft;
  Color get scrim => palette.scrim;
  Color get onScrim => palette.onScrim;
  List<Color> get heroGradient => palette.heroGradient;
  List<Color> get channels => palette.channels;
  List<BoxShadow> get shadow1 => palette.shadow1;
  List<BoxShadow> get shadow2 => palette.shadow2;

  /// Stable per-name hue for channels and real-name avatars, so the same
  /// channel or person always gets the same color.
  Color channelFor(String seed) {
    if (seed.isEmpty) {
      return channels.first;
    }
    int hash = 0;
    for (final int unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return channels[hash % channels.length];
  }

  @override
  ZxTokens copyWith({ZxPalette? palette}) => ZxTokens(palette ?? this.palette);

  // Theme changes swap the whole palette; interpolating dozens of roles buys
  // nothing visible, so switch at the midpoint.
  @override
  ZxTokens lerp(ThemeExtension<ZxTokens>? other, double t) {
    if (other is! ZxTokens) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}
