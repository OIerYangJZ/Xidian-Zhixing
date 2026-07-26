import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'design_tokens.dart';
import 'shared_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => lightThemeFor(const Locale('zh', 'CN'));

  static ThemeData get darkTheme => darkThemeFor(const Locale('zh', 'CN'));

  static ThemeData lightThemeFor(Locale locale) =>
      _buildTheme(SharedColors.light, Brightness.light, locale);

  static ThemeData darkThemeFor(Locale locale) =>
      _buildTheme(SharedColors.dark, Brightness.dark, locale);

  static ThemeData adminTheme(
    Brightness brightness, {
    Locale locale = const Locale('zh', 'CN'),
  }) {
    final EditorialColors base = brightness == Brightness.dark
        ? SharedColors.dark
        : SharedColors.light;
    return _buildTheme(
      base.copyWith(
        primary: brightness == Brightness.dark
            ? const Color(0xFF78B6C8)
            : SharedColors.adminPrimary,
        primaryActive: brightness == Brightness.dark
            ? const Color(0xFF9BCAD7)
            : const Color(0xFF173742),
        coral: brightness == Brightness.dark
            ? const Color(0xFFE0B66C)
            : SharedColors.adminAccent,
      ),
      brightness,
      locale,
    );
  }

  static ThemeData _buildTheme(
    EditorialColors palette,
    Brightness brightness,
    Locale locale,
  ) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: brightness == Brightness.light
          ? palette.onDarkPanel
          : palette.page,
      primaryContainer: palette.primarySubtle,
      onPrimaryContainer: palette.ink,
      secondary: palette.coral,
      onSecondary: palette.ink,
      secondaryContainer: palette.apricot,
      onSecondaryContainer: palette.ink,
      tertiary: palette.info,
      onTertiary: palette.page,
      tertiaryContainer: palette.infoSubtle,
      onTertiaryContainer: palette.ink,
      error: palette.danger,
      onError: palette.page,
      errorContainer: palette.primarySubtle,
      onErrorContainer: palette.ink,
      surface: palette.surface,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.primarySubtle,
      onSurfaceVariant: palette.mutedInk,
      outline: palette.line,
      outlineVariant: palette.line.withValues(alpha: 0.72),
      shadow: Colors.transparent,
      scrim: palette.ink.withValues(alpha: 0.5),
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
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        backgroundColor: palette.page,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        shape: Border(bottom: BorderSide(color: palette.line)),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: BorderSide(color: palette.line),
        ),
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: controlShape,
          backgroundColor: palette.darkPanel,
          foregroundColor: palette.onDarkPanel,
          disabledBackgroundColor: palette.line,
          disabledForegroundColor: palette.mutedInk,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: controlShape,
          foregroundColor: palette.ink,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: palette.ink),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: controlShape,
          foregroundColor: palette.ink,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.ink,
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        backgroundColor: palette.primary,
        foregroundColor: palette.page,
        shape: controlShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: palette.page,
        indicatorColor: palette.primarySubtle,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.mutedInk,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.page,
        indicatorColor: palette.primarySubtle,
        selectedIconTheme: IconThemeData(color: palette.primary),
        unselectedIconTheme: IconThemeData(color: palette.mutedInk),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: palette.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: palette.mutedInk,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        labelStyle: TextStyle(color: palette.mutedInk),
        floatingLabelStyle: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: palette.mutedInk),
        prefixIconColor: palette.mutedInk,
        suffixIconColor: palette.mutedInk,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.line),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
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
        surfaceTintColor: Colors.transparent,
        shape: controlShape,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
