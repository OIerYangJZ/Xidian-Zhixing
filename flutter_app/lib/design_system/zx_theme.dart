import 'dart:async';

import 'package:flutter/material.dart';

import 'zx_metrics.dart';
import 'zx_tokens.dart';

/// Builds the app [ThemeData] for one color theme and brightness. Material
/// widgets get the design system's colors and shapes from here; custom
/// widgets read [ZxTokens] directly.
abstract final class ZxTheme {
  static ThemeData build({
    required String themeKey,
    required Brightness brightness,
  }) {
    // Every entry point (web app, admin portal, Android) is themed here, so
    // this is where the web fallback font starts loading.
    unawaited(ZxFonts.loadDeferred());
    final ZxPalette p = zxPaletteFor(themeKey, brightness);
    final bool dark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primaryPressed,
      secondary: p.accent,
      onSecondary: p.accentInk,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.accentInk,
      tertiary: p.coral,
      onTertiary: p.onPrimary,
      error: p.danger,
      onError: p.onDanger,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.text2,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.raised,
      surfaceContainerHigh: p.raised,
      surfaceContainerHighest: p.bgSunk,
      outline: p.lineStrong,
      outlineVariant: p.line,
      shadow: dark ? Colors.black : const Color(0xFF462D19),
      scrim: p.scrim,
      inverseSurface: p.text,
      onInverseSurface: p.surface,
      inversePrimary: p.primarySoft,
    );

    final TextTheme text = TextTheme(
      displayLarge: ZxType.display,
      displayMedium: ZxType.display,
      displaySmall: ZxType.headline,
      headlineLarge: ZxType.headline,
      headlineMedium: ZxType.headline,
      headlineSmall: ZxType.titleLarge,
      titleLarge: ZxType.titleLarge,
      titleMedium: ZxType.title,
      titleSmall: ZxType.label,
      bodyLarge: ZxType.body,
      bodyMedium: ZxType.body,
      bodySmall: ZxType.caption,
      labelLarge: ZxType.label,
      labelMedium: ZxType.caption.copyWith(fontWeight: FontWeight.w600),
      labelSmall: ZxType.micro,
    ).apply(bodyColor: p.text, displayColor: p.text);

    const EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 12,
    );
    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: ZxRadius.buttonAll,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.line,
      textTheme: text,
      fontFamily: ZxFonts.body,
      fontFamilyFallback: ZxFonts.bodyFallback,
      extensions: <ThemeExtension<dynamic>>[ZxTokens(p)],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.glass,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: ZxType.title.copyWith(color: p.text),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ZxRadius.cardAll,
          side: BorderSide(color: p.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.bgSunk,
          disabledForegroundColor: p.text3,
          textStyle: ZxType.label,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          textStyle: ZxType.label,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.lineStrong),
          textStyle: ZxType.label,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: ZxType.label,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text2,
          minimumSize: const Size.square(ZxSize.iconButton),
          shape: RoundedRectangleBorder(borderRadius: ZxRadius.smallButtonAll),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.cardAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: ZxType.body.copyWith(color: p.text3),
        helperStyle: ZxType.caption.copyWith(color: p.text3),
        errorStyle: ZxType.caption.copyWith(color: p.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: ZxRadius.buttonAll,
          borderSide: BorderSide(color: p.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZxRadius.buttonAll,
          borderSide: BorderSide(color: p.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZxRadius.buttonAll,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: ZxRadius.buttonAll,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: ZxRadius.buttonAll,
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primarySoft,
        side: BorderSide(color: p.line),
        labelStyle: ZxType.caption.copyWith(color: p.text2),
        secondaryLabelStyle: ZxType.caption.copyWith(color: p.primary),
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.pillAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? p.onPrimary : p.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? p.primary : p.lineStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.bgSunk,
          foregroundColor: p.text2,
          selectedBackgroundColor: p.surface,
          selectedForegroundColor: p.text,
          side: BorderSide(color: p.line),
          textStyle: ZxType.label,
          shape: RoundedRectangleBorder(borderRadius: ZxRadius.smallButtonAll),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? p.primary : p.lineStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        side: BorderSide(color: p.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.badgeAll),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.text2,
        textColor: p.text,
        titleTextStyle: ZxType.body.copyWith(color: p.text),
        subtitleTextStyle: ZxType.caption.copyWith(color: p.text3),
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.buttonAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.raised,
        modalBarrierColor: p.scrim,
        showDragHandle: true,
        dragHandleColor: p.lineStrong,
        shape: const RoundedRectangleBorder(borderRadius: ZxRadius.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
        barrierColor: p.scrim,
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.sheetAll),
        titleTextStyle: ZxType.title.copyWith(color: p.text),
        contentTextStyle: ZxType.body.copyWith(color: p.text2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.buttonAll),
        textStyle: ZxType.body.copyWith(color: p.text),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: ZxType.body.copyWith(color: p.surface),
        actionTextColor: p.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: ZxRadius.buttonAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.text,
          borderRadius: ZxRadius.badgeAll,
        ),
        textStyle: ZxType.caption.copyWith(color: p.surface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.glass,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => ZxType.micro.copyWith(
            color: s.contains(WidgetState.selected) ? p.primary : p.text3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.primary : p.text3,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
        selectedIconTheme: IconThemeData(color: p.primary),
        unselectedIconTheme: IconThemeData(color: p.text3),
        selectedLabelTextStyle: ZxType.micro.copyWith(color: p.primary),
        unselectedLabelTextStyle: ZxType.micro.copyWith(color: p.text3),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.text3,
        labelStyle: ZxType.label,
        unselectedLabelStyle: ZxType.label.copyWith(
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: p.primary,
        dividerColor: p.line,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.danger,
        textColor: p.onDanger,
        textStyle: ZxType.micro,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.bgSunk,
        circularTrackColor: p.bgSunk,
      ),
    );
  }
}
