import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'shared_colors.dart';

class AppTheme {
  static const Color primary = SharedColors.primary;
  static const Color accent = SharedColors.accent;

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      primaryColor: primary,
      secondaryColor: accent,
      surface: SharedColors.surface,
      background: SharedColors.background,
      onSurface: SharedColors.textPrimary,
      divider: SharedColors.divider,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFFE3847C),
      secondaryColor: const Color(0xFF79B2BE),
      surface: const Color(0xFF1D1B1B),
      background: const Color(0xFF151414),
      onSurface: const Color(0xFFF4F0ED),
      divider: const Color(0xFF3B3735),
    );
  }

  static ThemeData adminTheme(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return _buildTheme(
      brightness: brightness,
      primaryColor: dark ? const Color(0xFF78B6C8) : SharedColors.adminPrimary,
      secondaryColor: dark ? const Color(0xFFE0B66C) : SharedColors.adminAccent,
      surface: dark ? const Color(0xFF182126) : const Color(0xFFFFFFFF),
      background: dark ? const Color(0xFF10181C) : const Color(0xFFF2F5F6),
      onSurface: dark ? const Color(0xFFEAF0F2) : const Color(0xFF1E2A30),
      divider: dark ? const Color(0xFF334249) : const Color(0xFFDCE4E7),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primaryColor,
    required Color secondaryColor,
    required Color surface,
    required Color background,
    required Color onSurface,
    required Color divider,
  }) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: brightness,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surface,
          error: SharedColors.danger,
        ).copyWith(
          onSurface: onSurface,
          surfaceContainerLowest: surface,
          surfaceContainerLow: background,
          outline: divider,
          outlineVariant: divider.withValues(alpha: 0.72),
        );

    final TextTheme textTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: onSurface.withValues(alpha: 0.66),
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'PingFang SC',
      fontFamilyFallback: const <String>[
        'Noto Sans CJK SC',
        'Microsoft YaHei',
        'Arial',
        'sans-serif',
      ],
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        backgroundColor: surface.withValues(alpha: 0.96),
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: divider),
        ),
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        backgroundColor: scheme.surface,
        side: BorderSide(color: divider),
        labelStyle: textTheme.labelMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: divider),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 44),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 1,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? SharedColors.surface
            : Colors.white.withValues(alpha: 0.05),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: divider),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: divider.withValues(alpha: 0.7)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF292727)
            : const Color(0xFFF2EEEB),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF292727),
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
        circularTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: TextStyle(color: surface, fontSize: 12),
      ),
    );
  }
}
