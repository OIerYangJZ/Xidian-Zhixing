import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/state/app_theme_store.dart';
import '../../design_system/design_system.dart';
import '../download/android_release_page.dart';
import '../legal/community_guidelines_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/report_guidelines_page.dart';
import '../legal/terms_of_service_page.dart';
import 'emoji_settings_page.dart';
import 'profile_page.dart';

/// 设置 (handoff W7): language, the four color themes as preview cards,
/// light / dark (web follows the system), emoji, account, rules, Android.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: Text(text('设置', 'Settings'))),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ZxListSection(
                      title: text('界面与偏好', 'Appearance and preferences'),
                      children: <Widget>[
                        ZxListItem(
                          icon: Icons.language_rounded,
                          iconColor: ZxTokens.of(context).info,
                          title: text('语言 · Language', 'Language · 语言'),
                          trailing: const _LanguageSwitch(),
                        ),
                        const _ThemePicker(),
                        ZxListItem(
                          icon: Icons.dark_mode_outlined,
                          iconColor: ZxTokens.of(context).text2,
                          title: text('明暗模式', 'Light and dark mode'),
                          subtitle: text(
                            '自动跟随浏览器与系统的浅色或深色模式',
                            'Automatically follows the browser and system appearance.',
                          ),
                          trailing: ZxBadge.level(text('跟随系统', 'System')),
                        ),
                        ZxListItem(
                          icon: Icons.emoji_emotions_outlined,
                          iconColor: ZxTokens.of(context).accentInk,
                          title: text('表情与输入', 'Emoji and input'),
                          onTap: () => open(const EmojiSettingsPage()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ZxListSection(
                      title: text('账号', 'Account'),
                      children: <Widget>[
                        ZxListItem(
                          icon: Icons.person_outline_rounded,
                          iconColor: ZxTokens.of(context).success,
                          title: text('个人资料与隐私', 'Profile and privacy'),
                          onTap: () => open(const ProfilePage()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ZxListSection(
                      title: text('规则与隐私', 'Rules and privacy'),
                      children: <Widget>[
                        ZxListItem(
                          icon: Icons.description_outlined,
                          iconColor: ZxTokens.of(context).text2,
                          title: text('用户协议', 'Terms of Service'),
                          onTap: () => open(const TermsOfServicePage()),
                        ),
                        ZxListItem(
                          icon: Icons.shield_outlined,
                          iconColor: ZxTokens.of(context).text2,
                          title: text('隐私政策', 'Privacy Policy'),
                          onTap: () => open(const PrivacyPolicyPage()),
                        ),
                        ZxListItem(
                          icon: Icons.groups_outlined,
                          iconColor: ZxTokens.of(context).text2,
                          title: text('社区规范', 'Community Guidelines'),
                          onTap: () => open(const CommunityGuidelinesPage()),
                        ),
                        ZxListItem(
                          icon: Icons.flag_outlined,
                          iconColor: ZxTokens.of(context).text2,
                          title: text('举报说明', 'Reporting Guidelines'),
                          onTap: () => open(const ReportGuidelinesPage()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ZxCard(
                      padding: const EdgeInsets.all(4),
                      color: Color.lerp(
                        ZxTokens.of(context).surface,
                        ZxTokens.of(context).accentSoft,
                        0.6,
                      ),
                      child: ZxListItem(
                        icon: Icons.download_rounded,
                        iconColor: ZxTokens.of(context).success,
                        title: text('下载 Android 客户端', 'Get the Android app'),
                        onTap: () => open(const AndroidReleasePage()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 中文 / English, applied at once.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('中文')),
        ButtonSegment<bool>(value: true, label: Text('English')),
      ],
      selected: <bool>{english},
      onSelectionChanged: (Set<bool> value) =>
          AppLocaleStore.instance.setLocale(
            value.first ? const Locale('en') : const Locale('zh', 'CN'),
          ),
    );
  }
}

/// 配色主题: a 2 × 2 grid of preview cards, saved on this device.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return ListenableBuilder(
      listenable: AppThemeStore.instance,
      builder: (BuildContext context, _) {
        final String current = AppThemeStore.instance.themeKey;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color.lerp(t.primary, t.surface, 0.88),
                      borderRadius: ZxRadius.smallButtonAll,
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 18,
                      color: t.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      uiText(context, zh: '配色主题', en: 'Color theme'),
                      style: ZxType.body.copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    uiText(context, zh: '保存在本机', en: 'Saved on this device'),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final double width = (c.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      for (final ZxThemeInfo theme in zxThemes)
                        SizedBox(
                          width: width,
                          child: _ThemeCard(
                            theme: theme,
                            preview: theme.light,
                            selected: theme.key == current,
                            label: locale.languageCode == 'en'
                                ? theme.labelEn
                                : theme.labelZh,
                            description: locale.languageCode == 'en'
                                ? theme.descriptionEn
                                : theme.descriptionZh,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.preview,
    required this.selected,
    required this.label,
    required this.description,
  });

  final ZxThemeInfo theme;

  /// Always the light palette, so the swatch reads as the theme's paper.
  final ZxPalette preview;
  final bool selected;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: t.bgSunk,
        borderRadius: ZxRadius.buttonAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('theme-card-${theme.key}'),
          onTap: () => AppThemeStore.instance.setThemeKey(theme.key),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: ZxRadius.buttonAll,
              border: Border.all(
                color: selected ? t.primary : t.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 64,
                  color: preview.bg,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Stack(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 70,
                            height: 5,
                            decoration: BoxDecoration(
                              color: preview.text2,
                              borderRadius: ZxRadius.pillAll,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 110,
                            height: 4,
                            decoration: BoxDecoration(
                              color: preview.lineStrong,
                              borderRadius: ZxRadius.pillAll,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: preview.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: preview.primary,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Positioned(
                          left: -2,
                          top: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: t.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: t.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZxType.label.copyWith(color: t.text),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZxType.micro.copyWith(
                          color: t.text3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
