import 'package:flutter/material.dart';

/// 跨端共享的品牌颜色常量
/// 两端主题均引用此文件，确保品牌色彩一致
class SharedColors {
  SharedColors._();

  /// 人本·初创：当前朱赤、暖白与杏黄体系。
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

  /// 书院·青绿：安静、清润的书院青绿体系。
  static const EditorialColors academyTealLight = EditorialColors(
    page: Color(0xFFF3F7F2),
    surface: Color(0xFFFFFEF9),
    ink: Color(0xFF202A23),
    mutedInk: Color(0xFF657168),
    line: Color(0xFFD3DED2),
    primary: Color(0xFF426F52),
    primaryActive: Color(0xFF2D5139),
    coral: Color(0xFF71967B),
    apricot: Color(0xFFD4A955),
    primarySubtle: Color(0xFFE0EBDF),
    infoSubtle: Color(0xFFE3ECE9),
    darkPanel: Color(0xFF203128),
    onDarkPanel: Color(0xFFF3F7F2),
    success: Color(0xFF426F52),
    warning: Color(0xFF8A641F),
    danger: Color(0xFF963D36),
    info: Color(0xFF4F7480),
  );

  static const EditorialColors academyTealDark = EditorialColors(
    page: Color(0xFF151A16),
    surface: Color(0xFF1D241F),
    ink: Color(0xFFF0F4EE),
    mutedInk: Color(0xFFB4BEB2),
    line: Color(0xFF414D43),
    primary: Color(0xFF91C29C),
    primaryActive: Color(0xFFB2D8B9),
    coral: Color(0xFF7FAB8A),
    apricot: Color(0xFFD9B568),
    primarySubtle: Color(0xFF27382B),
    infoSubtle: Color(0xFF263638),
    darkPanel: Color(0xFFEDF3EA),
    onDarkPanel: Color(0xFF182019),
    success: Color(0xFF91C29C),
    warning: Color(0xFFE0BA70),
    danger: Color(0xFFE38B82),
    info: Color(0xFF8CB7C0),
  );

  /// 杏黄·纸韵：温和、明亮的杏黄纸本体系。
  static const EditorialColors apricotPaperLight = EditorialColors(
    page: Color(0xFFFBF6EA),
    surface: Color(0xFFFFFEF8),
    ink: Color(0xFF30281E),
    mutedInk: Color(0xFF766A5B),
    line: Color(0xFFE4D5B9),
    primary: Color(0xFF94631F),
    primaryActive: Color(0xFF694513),
    coral: Color(0xFFC38D3B),
    apricot: Color(0xFFE3B660),
    primarySubtle: Color(0xFFF2E2BF),
    infoSubtle: Color(0xFFE8ECE4),
    darkPanel: Color(0xFF342B20),
    onDarkPanel: Color(0xFFFBF6EA),
    success: Color(0xFF55715B),
    warning: Color(0xFF94631F),
    danger: Color(0xFF963D36),
    info: Color(0xFF55747B),
  );

  static const EditorialColors apricotPaperDark = EditorialColors(
    page: Color(0xFF1B1812),
    surface: Color(0xFF252118),
    ink: Color(0xFFF6F0E3),
    mutedInk: Color(0xFFC2B7A4),
    line: Color(0xFF504838),
    primary: Color(0xFFE1B665),
    primaryActive: Color(0xFFF0CE89),
    coral: Color(0xFFD39D4B),
    apricot: Color(0xFFEAC777),
    primarySubtle: Color(0xFF3D321E),
    infoSubtle: Color(0xFF2C3430),
    darkPanel: Color(0xFFF3EBD9),
    onDarkPanel: Color(0xFF221D15),
    success: Color(0xFF98B49E),
    warning: Color(0xFFE1B665),
    danger: Color(0xFFE38B82),
    info: Color(0xFF8DB6BD),
  );

  /// 墨朱·新页：移植自远端 main 的新讨论界面配色。
  static const EditorialColors discussionLight = EditorialColors(
    page: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF191917),
    mutedInk: Color(0xFF6F706B),
    line: Color(0xFFE8E8E4),
    primary: Color(0xFFAB3E36),
    primaryActive: Color(0xFF852E29),
    coral: Color(0xFFD87569),
    apricot: Color(0xFFE6B75D),
    primarySubtle: Color(0xFFFAECE9),
    infoSubtle: Color(0xFFEEF3F4),
    darkPanel: Color(0xFF191917),
    onDarkPanel: Color(0xFFFFFEFB),
    success: Color(0xFF387157),
    warning: Color(0xFF9A681E),
    danger: Color(0xFFAF3E36),
    info: Color(0xFF356B80),
  );

  static const EditorialColors discussionDark = EditorialColors(
    page: Color(0xFF151513),
    surface: Color(0xFF1D1D1B),
    ink: Color(0xFFF5F5F0),
    mutedInk: Color(0xFFB7B8B1),
    line: Color(0xFF343430),
    primary: Color(0xFFE37D73),
    primaryActive: Color(0xFFF0A096),
    coral: Color(0xFFF09A8E),
    apricot: Color(0xFFE9C26E),
    primarySubtle: Color(0xFF432B28),
    infoSubtle: Color(0xFF243337),
    darkPanel: Color(0xFF0F0F0E),
    onDarkPanel: Color(0xFFF8F8F3),
    success: Color(0xFF83B894),
    warning: Color(0xFFE8BD6B),
    danger: Color(0xFFE98C84),
    info: Color(0xFF8CBBC6),
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
class AppColorThemeOption {
  const AppColorThemeOption({
    required this.key,
    required this.labelZh,
    required this.labelEn,
    required this.descriptionZh,
    required this.descriptionEn,
    required this.previewColors,
  });

  final String key;
  final String labelZh;
  final String labelEn;
  final String descriptionZh;
  final String descriptionEn;
  final List<Color> previewColors;

  String labelFor(Locale locale) =>
      locale.languageCode == 'en' ? labelEn : labelZh;

  String descriptionFor(Locale locale) =>
      locale.languageCode == 'en' ? descriptionEn : descriptionZh;
}

class AppColorThemes {
  AppColorThemes._();

  static const String defaultKey = 'zhushachi';

  static const List<AppColorThemeOption> options = <AppColorThemeOption>[
    AppColorThemeOption(
      key: 'zhushachi',
      labelZh: '人本·初创',
      labelEn: 'Humanist · Founding',
      descriptionZh: '朱赤、暖白与杏黄，保留当前人本气质',
      descriptionEn: 'Vermilion, warm white, and apricot',
      previewColors: <Color>[
        Color(0xFFA43B32),
        Color(0xFFF7F6F2),
        Color(0xFFE8B65D),
      ],
    ),
    AppColorThemeOption(
      key: 'zhuqing',
      labelZh: '书院·青绿',
      labelEn: 'Academy · Teal',
      descriptionZh: '沉静青绿与纸白，适合长时间阅读',
      descriptionEn: 'Quiet teal and paper white for long reading',
      previewColors: <Color>[
        Color(0xFF426F52),
        Color(0xFFF3F7F2),
        Color(0xFFD4A955),
      ],
    ),
    AppColorThemeOption(
      key: 'xingrenhuang',
      labelZh: '杏黄·纸韵',
      labelEn: 'Apricot · Paper',
      descriptionZh: '古朴杏黄与墨褐，温暖但不喧闹',
      descriptionEn: 'Bookish apricot with restrained ink brown',
      previewColors: <Color>[
        Color(0xFF94631F),
        Color(0xFFFBF6EA),
        Color(0xFFC38D3B),
      ],
    ),
    AppColorThemeOption(
      key: 'mozhuxinye',
      labelZh: '墨朱·新页',
      labelEn: 'Ink Vermilion · New',
      descriptionZh: '远端新版的连续讨论流与墨朱金界面',
      descriptionEn: 'The new continuous discussion UI from remote main',
      previewColors: <Color>[
        Color(0xFFAB3E36),
        Color(0xFFFFFFFF),
        Color(0xFFE6B75D),
      ],
    ),
  ];

  static bool isSupported(String key) =>
      options.any((AppColorThemeOption option) => option.key == key);

  static AppColorThemeOption optionFor(String key) {
    for (final AppColorThemeOption option in options) {
      if (option.key == key) {
        return option;
      }
    }
    throw ArgumentError.value(key, 'key', 'Unsupported color theme');
  }

  /// 显式迁移旧版已发布主题，不吞掉未知值。
  static String resolveStoredKey(String? key) {
    return switch (key) {
      null || '' => defaultKey,
      'zhushachi' || 'zhuqing' || 'xingrenhuang' || 'mozhuxinye' => key,
      'haiyanqing' => 'zhuqing',
      'minimal' ||
      'yanzhihong' ||
      'chitaonuan' ||
      'zaonihong' ||
      'xuanzhizhu' ||
      'ouhezi' ||
      'mohui' => defaultKey,
      _ => throw StateError('Unknown stored color theme: $key'),
    };
  }

  static EditorialColors lightFor(String key) {
    return switch (key) {
      'zhushachi' => SharedColors.light,
      'zhuqing' => SharedColors.academyTealLight,
      'xingrenhuang' => SharedColors.apricotPaperLight,
      'mozhuxinye' => SharedColors.discussionLight,
      _ => throw ArgumentError.value(key, 'key', 'Unsupported color theme'),
    };
  }

  static EditorialColors darkFor(String key) {
    return switch (key) {
      'zhushachi' => SharedColors.dark,
      'zhuqing' => SharedColors.academyTealDark,
      'xingrenhuang' => SharedColors.apricotPaperDark,
      'mozhuxinye' => SharedColors.discussionDark,
      _ => throw ArgumentError.value(key, 'key', 'Unsupported color theme'),
    };
  }

  /// The discussion shell is the single Web experience across every theme.
  /// Themes only provide color tokens; they must not switch the application
  /// back to the retired AppBar/NavigationBar shell on narrow viewports.
  static bool usesDiscussionLayout(String key) => true;
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
