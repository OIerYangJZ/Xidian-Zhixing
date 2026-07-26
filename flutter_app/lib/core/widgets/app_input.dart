import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// The single input decoration used across the web client.
///
/// Field labels are deliberately expressed as concise placeholders so forms
/// retain an open, single-layer rhythm instead of accumulating Material cards,
/// floating captions, and leading icon containers.
class AppInput {
  AppInput._();

  static InputDecoration decoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
    int? counterMaxLength,
  }) => InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    helperText: helperText,
    counterText: counterMaxLength == null ? null : '',
  );

  /// Shared geometry for every search field.
  ///
  /// Each caller keeps its own surface and text colors while the search
  /// affordance retains one compact, full-pill silhouette across the client.
  static InputDecoration searchDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextStyle? hintStyle,
    Color? fillColor,
    Color? focusedBorderColor,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon ?? const Icon(Icons.search_rounded),
      suffixIcon: suffixIcon,
      filled: fillColor == null ? null : true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: focusedBorderColor == null
          ? border
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              borderSide: BorderSide(color: focusedBorderColor),
            ),
    );
  }

  /// Compact one-line editor used for inline replies in social timelines.
  static InputDecoration inlineComposerDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border,
    );
  }
}
