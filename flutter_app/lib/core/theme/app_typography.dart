import 'package:flutter/material.dart';

/// The only font families used by the product.
///
/// Font selection is locale-aware so Chinese and English never fall through to
/// an unrelated system UI font. The accent face is intentionally reserved for
/// short signatures and quotes.
class AppTypography {
  AppTypography._();

  static const String chineseDisplay = 'STZhongsong';
  static const String chineseBody = 'STSong';
  static const String chineseAccent = 'STKaiti';
  static const List<String> chineseDisplayFallback = <String>[
    '华文中宋',
    'STSong',
    '华文宋体',
    'SimSun',
    '宋体',
  ];
  static const List<String> chineseBodyFallback = <String>[
    '华文宋体',
    'SimSun',
    '宋体',
  ];

  static const String englishDisplay = 'Anthropic Serif Web';
  static const String englishBody = 'Times New Roman';
  static const String englishAccent = 'Apple Chancery';
  static const List<String> englishDisplayFallback = <String>[
    'Anthropic Serif Web Text',
    'Times New Roman',
  ];
  static const List<String> englishBodyFallback = <String>[
    'Anthropic Serif Web',
  ];

  static bool isEnglish(Locale locale) => locale.languageCode == 'en';

  static String displayFamily(Locale locale) =>
      isEnglish(locale) ? englishDisplay : chineseDisplay;

  static List<String> displayFallback(Locale locale) =>
      isEnglish(locale) ? englishDisplayFallback : chineseDisplayFallback;

  static String bodyFamily(Locale locale) =>
      isEnglish(locale) ? englishBody : chineseBody;

  static List<String> bodyFallback(Locale locale) =>
      isEnglish(locale) ? englishBodyFallback : chineseBodyFallback;

  static String accentFamily(Locale locale) =>
      isEnglish(locale) ? englishAccent : chineseAccent;

  static TextStyle accentStyle(
    Locale locale, {
    double? fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: accentFamily(locale),
      fontFamilyFallback: bodyFallback(locale),
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  static TextTheme textTheme(Locale locale, Color foreground) {
    TextStyle display({
      required double size,
      required double height,
      FontWeight weight = FontWeight.w600,
      double? letterSpacing,
    }) {
      return TextStyle(
        fontFamily: displayFamily(locale),
        fontFamilyFallback: displayFallback(locale),
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: foreground,
      );
    }

    TextStyle body({
      required double size,
      required double height,
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: bodyFamily(locale),
        fontFamilyFallback: bodyFallback(locale),
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color ?? foreground,
      );
    }

    return TextTheme(
      displayLarge: display(
        size: 64,
        height: 0.98,
        weight: FontWeight.w600,
        letterSpacing: isEnglish(locale) ? -1.4 : -0.8,
      ),
      displayMedium: display(
        size: 48,
        height: 1.04,
        weight: FontWeight.w600,
        letterSpacing: isEnglish(locale) ? -1.0 : -0.5,
      ),
      displaySmall: display(
        size: 36,
        height: 1.12,
        weight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineMedium: display(size: 28, height: 1.22),
      headlineSmall: display(size: 24, height: 1.3),
      titleLarge: display(size: 21, height: 1.35),
      titleMedium: display(size: 17, height: 1.45),
      titleSmall: body(size: 15, height: 1.45, weight: FontWeight.w600),
      bodyLarge: body(size: 17, height: 1.65),
      bodyMedium: body(size: 15, height: 1.6),
      bodySmall: body(
        size: 13,
        height: 1.5,
        color: foreground.withValues(alpha: 0.68),
      ),
      labelLarge: body(size: 14, height: 1.25, weight: FontWeight.w600),
      labelMedium: body(size: 12, height: 1.25, weight: FontWeight.w600),
      labelSmall: body(
        size: 11,
        height: 1.25,
        weight: FontWeight.w600,
        color: foreground.withValues(alpha: 0.62),
      ),
    );
  }
}
