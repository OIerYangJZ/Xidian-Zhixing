import 'package:flutter/material.dart';
import '../common/feature_section.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/state/app_theme_store.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/theme_dropdown.dart';
import '../../core/widgets/language_toggle.dart';
import '../legal/community_guidelines_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/report_guidelines_page.dart';
import '../legal/terms_of_service_page.dart';
import 'emoji_settings_page.dart';
import '../campus/campus_auth_center_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    return Scaffold(
      appBar: AppBar(title: Text(text('设置', 'Settings'))),
      body: AppPageFrame(
        maxWidth: AppLayout.formMaxWidth,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            AppSectionHeader(title: text('账号与认证', 'Account and sign-in')),
            _SettingsLink(
              icon: Icons.key_outlined,
              title: text('校园系统登录', 'Campus system sign-in'),
              page: const CampusAuthCenterPage(),
            ),
            const Divider(height: 32),
            AppSectionHeader(
              title: text('界面与偏好', 'Appearance and preferences'),
            ),
            const SizedBox(height: AppSpacing.md),
            FeatureSection(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: Text(text('语言', 'Language')),
                    trailing: LanguageToggle(
                      locale: Localizations.localeOf(context),
                      compact: true,
                      onChanged: AppLocaleStore.instance.setLocale,
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                    title: Text(text('显示模式', 'Display mode')),
                    trailing: Switch(
                      value: AppThemeStore.instance.mode == ThemeMode.dark,
                      onChanged: (bool value) => AppThemeStore.instance.setMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ListenableBuilder(
                      listenable: AppThemeStore.instance,
                      builder: (BuildContext context, Widget? child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              text('配色主题', 'Color theme'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ThemeDropdown(
                              themeKey: AppThemeStore.instance.themeKey,
                              locale: Localizations.localeOf(context),
                              expanded: true,
                              onChanged: AppThemeStore.instance.setThemeKey,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_emotions_outlined),
                    title: Text(text('表情与输入', 'Emoji and input')),
                    subtitle: Text(
                      text(
                        '设置常用表情和输入面板',
                        'Manage favorite emoji and the input panel.',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EmojiSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSectionHeader(title: text('规则与隐私', 'Rules and privacy')),
            const SizedBox(height: AppSpacing.sm),
            FeatureSection(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _SettingsLink(
                    icon: Icons.description_outlined,
                    title: text('用户协议', 'Terms of Service'),
                    page: const TermsOfServicePage(),
                  ),
                  _SettingsLink(
                    icon: Icons.shield_outlined,
                    title: text('隐私政策', 'Privacy Policy'),
                    page: const PrivacyPolicyPage(),
                  ),
                  _SettingsLink(
                    icon: Icons.groups_outlined,
                    title: text('社区规范', 'Community Guidelines'),
                    page: const CommunityGuidelinesPage(),
                  ),
                  _SettingsLink(
                    icon: Icons.flag_outlined,
                    title: text('举报说明', 'Reporting Guidelines'),
                    page: const ReportGuidelinesPage(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.page,
  });

  final IconData icon;
  final String title;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page));
      },
    );
  }
}
