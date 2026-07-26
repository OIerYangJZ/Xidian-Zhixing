import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/state/web_theme_store.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
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
            AppSurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListenableBuilder(
                    listenable: WebThemeStore.instance,
                    builder: (BuildContext context, Widget? child) {
                      final WebThemeStore store = WebThemeStore.instance;
                      return ListTile(
                        leading: const Icon(Icons.brightness_auto_outlined),
                        title: const Text('界面主题'),
                        subtitle: Text(_themeModeLabel(store.themeMode)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openAppearanceSheet(context),
                      );
                    },
                  ),
                  Divider(height: 1, color: EditorialColors.of(context).line),
                  ListenableBuilder(
                    listenable: WebThemeStore.instance,
                    builder: (BuildContext context, Widget? child) {
                      final AppThemePreset preset =
                          WebThemeStore.instance.preset;
                      return ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('主题方案'),
                        subtitle: Text('${preset.label} · 可在后续版本加入更多方案'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openPresetSheet(context),
                      );
                    },
                  ),
                  Divider(height: 1, color: EditorialColors.of(context).line),
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
            AppSurfaceCard(
              padding: EdgeInsets.zero,
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

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统设置',
  ThemeMode.light => '浅色模式',
  ThemeMode.dark => '深色模式',
};

void _openAppearanceSheet(BuildContext context) {
  final WebThemeStore store = WebThemeStore.instance;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? child) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('界面主题', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ThemeMode>(
              groupValue: store.themeMode,
              onChanged: (ThemeMode? next) {
                if (next == null) return;
                store.setThemeMode(next);
                Navigator.of(context).pop();
              },
              child: Column(
                children: <Widget>[
                  for (final ThemeMode mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(_themeModeLabel(mode)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openPresetSheet(BuildContext context) {
  final WebThemeStore store = WebThemeStore.instance;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? child) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('主题方案', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<String>(
              groupValue: store.preset.id,
              onChanged: (String? id) {
                if (id == null) return;
                store.setPreset(id);
                Navigator.of(context).pop();
              },
              child: Column(
                children: <Widget>[
                  for (final AppThemePreset preset in AppThemePresets.all)
                    RadioListTile<String>(
                      value: preset.id,
                      title: Text(preset.label),
                      subtitle: const Text('纯白画布、墨黑内容区、朱砂与金色强调'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
