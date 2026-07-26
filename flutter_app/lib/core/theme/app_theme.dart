import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'design_tokens.dart';
import 'shared_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightThemeFor(Locale locale, {AppThemePreset? preset}) =>
      _buildTheme(
        (preset ?? AppThemePresets.inkVermilion).light,
        Brightness.light,
        locale,
      );

  static ThemeData darkThemeFor(Locale locale, {AppThemePreset? preset}) =>
      _buildTheme(
        (preset ?? AppThemePresets.inkVermilion).dark,
        Brightness.dark,
        locale,
      );

  static ThemeData adminTheme(
    Brightness brightness, {
    Locale locale = const Locale('zh', 'CN'),
  }) => _buildTheme(
    brightness == Brightness.dark
        ? AppThemePresets.inkVermilion.dark
        : AppThemePresets.inkVermilion.light,
    brightness,
    locale,
  );

  static ThemeData _buildTheme(
    EditorialColors palette,
    Brightness brightness,
    Locale locale,
  ) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onDarkPanel,
      primaryContainer: palette.primarySubtle,
      onPrimaryContainer: palette.primaryActive,
      secondary: palette.apricot,
      onSecondary: palette.darkPanel,
      secondaryContainer: palette.infoSubtle,
      onSecondaryContainer: palette.ink,
      tertiary: palette.info,
      onTertiary: palette.onDarkPanel,
      tertiaryContainer: palette.infoSubtle,
      onTertiaryContainer: palette.ink,
      error: palette.danger,
      onError: palette.onDarkPanel,
      errorContainer: palette.danger.withValues(alpha: 0.12),
      onErrorContainer: palette.danger,
      surface: palette.surface,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.surfaceRaised,
      onSurfaceVariant: palette.mutedInk,
      outline: palette.line,
      outlineVariant: palette.line,
      shadow: palette.darkPanel,
      scrim: palette.darkPanel.withValues(alpha: 0.56),
      inverseSurface: palette.darkPanel,
      onInverseSurface: palette.onDarkPanel,
      inversePrimary: palette.coral,
    );
    final TextTheme textTheme = AppTypography.textTheme(locale, palette.ink);
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.bodyFamily(locale),
      fontFamilyFallback: AppTypography.bodyFallback(locale),
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.page,
      dividerColor: palette.line,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[palette],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        surfaceTintColor: palette.surface,
        titleTextStyle: textTheme.titleMedium,
        shape: Border(bottom: BorderSide(color: palette.line)),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        elevation: 0,
        color: palette.surfaceRaised,
        surfaceTintColor: palette.surfaceRaised,
        shadowColor: palette.darkPanel,
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 44),
              elevation: 0,
              shape: controlShape,
              backgroundColor: palette.primary,
              foregroundColor: palette.onDarkPanel,
              disabledBackgroundColor: palette.line,
              disabledForegroundColor: palette.faintInk,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                palette.primaryActive.withValues(alpha: 0.16),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          elevation: 0,
          shape: controlShape,
          foregroundColor: palette.ink,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: palette.line),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: controlShape,
          foregroundColor: palette.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          foregroundColor: palette.ink,
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        backgroundColor: palette.primary,
        foregroundColor: palette.onDarkPanel,
        shape: controlShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: palette.surface,
        indicatorColor: palette.primarySubtle,
        surfaceTintColor: palette.surface,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.mutedInk,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceRaised,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: TextStyle(color: palette.faintInk),
        suffixIconColor: palette.mutedInk,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.line),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 18,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        selectedColor: palette.primarySubtle,
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.line),
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.darkPanel,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onDarkPanel,
        ),
        shape: controlShape,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: palette.surface,
        shape: controlShape,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.primarySubtle,
        circularTrackColor: palette.primarySubtle,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: palette.darkPanel,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: palette.onDarkPanel),
      ),
    );
  }
}
