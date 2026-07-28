import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_theme_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/theme_dropdown.dart';
import '../legal/community_guidelines_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/report_guidelines_page.dart';
import '../legal/terms_of_service_page.dart';
import 'emoji_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: AppPageFrame(
        maxWidth: AppLayout.formMaxWidth,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const AppSectionHeader(
              title: '界面与偏好',
              subtitle: '网页端设置不会改变 Android、iOS 或微信小程序。',
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ListenableBuilder(
                      listenable: AppThemeStore.instance,
                      builder: (BuildContext context, Widget? child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '配色主题',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '使用下拉列表切换整套语义配色，选择会保存在当前设备。',
                              style: Theme.of(context).textTheme.bodySmall,
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
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.brightness_auto_outlined),
                    title: Text('明暗模式'),
                    subtitle: Text('自动跟随浏览器与系统的浅色或深色模式'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_emotions_outlined),
                    title: const Text('表情与输入'),
                    subtitle: const Text('设置常用表情和输入面板'),
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
            const AppSectionHeader(
              title: '规则与隐私',
              subtitle: '了解社区边界、举报流程与数据处理方式。',
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: <Widget>[
                  _SettingsLink(
                    icon: Icons.description_outlined,
                    title: '用户协议',
                    page: const TermsOfServicePage(),
                  ),
                  _SettingsLink(
                    icon: Icons.shield_outlined,
                    title: '隐私政策',
                    page: const PrivacyPolicyPage(),
                  ),
                  _SettingsLink(
                    icon: Icons.groups_outlined,
                    title: '社区规范',
                    page: const CommunityGuidelinesPage(),
                  ),
                  _SettingsLink(
                    icon: Icons.flag_outlined,
                    title: '举报说明',
                    page: const ReportGuidelinesPage(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppInlineMessage(
              title: '内测状态',
              message: '当前仅向项目组白名单账号开放，学校一站式登录尚未启用。',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '西电知行 v${AppConfig.appVersion}\n校园社区内测项目 · 非西电官方应用',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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
