import 'package:flutter/material.dart';

import '../../core/state/app_locale_store.dart';
import '../../core/state/web_theme_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import 'account_settings_panel.dart';
import 'privacy_notification_settings_panel.dart';
import '../legal/community_guidelines_page.dart';
import '../legal/privacy_policy_page.dart';
import '../legal/report_guidelines_page.dart';
import '../legal/terms_of_service_page.dart';
import 'emoji_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedId = 'appearance';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= AppBreakpoints.medium;
          final Widget detail = _SettingsDetail(selectedId: _selectedId);
          if (!desktop) {
            return SafeArea(
              child: Column(
                children: <Widget>[
                  _CompactSettingsBar(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: detail),
                ],
              ),
            );
          }
          return Row(
            children: <Widget>[
              SizedBox(
                width: 348,
                child: _SettingsNavigation(
                  onBack: () => Navigator.of(context).pop(),
                  controller: _searchController,
                  query: _query,
                  selectedId: _selectedId,
                  onQueryChanged: (String value) => setState(() {
                    _query = value.trim().toLowerCase();
                  }),
                  onSelected: (String id) => setState(() {
                    _selectedId = id;
                  }),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: colors.line),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }
}

class _CompactSettingsBar extends StatelessWidget {
  const _CompactSettingsBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: EditorialColors.of(context).line),
      ),
    ),
    child: Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('设置', style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.onBack,
    required this.controller,
    required this.query,
    required this.selectedId,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final TextEditingController controller;
  final String query;
  final String selectedId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;

  static const List<_SettingsDestination> _destinations =
      <_SettingsDestination>[
        _SettingsDestination(
          id: 'account',
          section: '账户',
          icon: Icons.manage_accounts_outlined,
          label: '账户与资料',
          keywords: '账户 资料 昵称 头像 密码 统一认证 校园账号',
        ),
        _SettingsDestination(
          id: 'privacyNotifications',
          section: '账户',
          icon: Icons.notifications_outlined,
          label: '隐私与通知',
          keywords: '隐私 私信 联系 通知 评论 点赞 收藏 举报',
        ),
        _SettingsDestination(
          id: 'appearance',
          section: '使用偏好',
          icon: Icons.palette_outlined,
          label: '界面与主题',
          keywords: '主题 深色 浅色 外观',
        ),
        _SettingsDestination(
          id: 'language',
          section: '使用偏好',
          icon: Icons.language_rounded,
          label: '语言',
          keywords: '中文 English 语言',
        ),
        _SettingsDestination(
          id: 'input',
          section: '使用偏好',
          icon: Icons.emoji_emotions_outlined,
          label: '表情与输入',
          keywords: '表情 输入 键盘',
        ),
        _SettingsDestination(
          id: 'privacy',
          section: '规则与隐私',
          icon: Icons.shield_outlined,
          label: '规则与政策',
          keywords: '规则 政策 举报 协议 社区',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final List<_SettingsDestination> visible = _destinations
        .where((item) {
          if (query.isEmpty) return true;
          return '${item.label} ${item.keywords}'.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return ColoredBox(
      color: colors.darkPanel,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: onBack,
                  tooltip: '返回',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.onDarkPanel,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '设置',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onDarkPanel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              onChanged: onQueryChanged,
              style: TextStyle(color: colors.onDarkPanel),
              decoration: AppInput.searchDecoration(
                hintText: '搜索设置',
                hintStyle: TextStyle(
                  color: colors.onDarkPanel.withValues(alpha: 0.56),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.onDarkPanel.withValues(alpha: 0.68),
                ),
                fillColor: colors.railSelected,
                focusedBorderColor: colors.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (int index = 0; index < visible.length; index++) ...<Widget>[
              if (index == 0 ||
                  visible[index - 1].section !=
                      visible[index].section) ...<Widget>[
                if (index != 0) const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    visible[index].section,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onDarkPanel.withValues(alpha: 0.52),
                    ),
                  ),
                ),
              ],
              _SettingsNavigationItem(
                destination: visible[index],
                selected: selectedId == visible[index].id,
                onTap: () => onSelected(visible[index].id),
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsNavigationItem extends StatelessWidget {
  const _SettingsNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _SettingsDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: colors.darkPanel.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.standard),
          curve: AppMotion.emphasis,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(),
          child: Row(
            children: <Widget>[
              Icon(
                destination.icon,
                color: selected ? colors.onDarkPanel : colors.railMuted,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? colors.onDarkPanel : colors.railMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDetail extends StatelessWidget {
  const _SettingsDetail({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context) {
    if (selectedId == 'account') {
      return const AccountSettingsPanel();
    }
    if (selectedId == 'privacyNotifications') {
      return const PrivacyNotificationSettingsPanel();
    }
    final _SettingsDetailContent content = switch (selectedId) {
      'input' => const _SettingsDetailContent(
        title: '表情与输入',
        sections: <_SettingsDetailSection>[
          _SettingsDetailSection(
            title: '输入体验',
            items: <_SettingsDetailItem>[
              _SettingsDetailItem(
                icon: Icons.emoji_emotions_outlined,
                title: '表情设置',
                subtitle: '管理常用表情和输入面板',
                destination: _SettingsPageDestination.emoji,
              ),
            ],
          ),
        ],
      ),
      'language' => const _SettingsDetailContent(
        title: '语言',
        sections: <_SettingsDetailSection>[
          _SettingsDetailSection(
            title: '显示语言',
            items: <_SettingsDetailItem>[
              _SettingsDetailItem(
                icon: Icons.language_rounded,
                title: '应用语言',
                destination: _SettingsPageDestination.locale,
              ),
            ],
          ),
        ],
      ),
      'privacy' => const _SettingsDetailContent(
        title: '规则与政策',
        sections: <_SettingsDetailSection>[
          _SettingsDetailSection(
            title: '规则与隐私',
            items: <_SettingsDetailItem>[
              _SettingsDetailItem(
                icon: Icons.description_outlined,
                title: '用户协议',
                destination: _SettingsPageDestination.terms,
              ),
              _SettingsDetailItem(
                icon: Icons.shield_outlined,
                title: '隐私政策',
                destination: _SettingsPageDestination.privacy,
              ),
              _SettingsDetailItem(
                icon: Icons.groups_outlined,
                title: '社区规范',
                destination: _SettingsPageDestination.guidelines,
              ),
              _SettingsDetailItem(
                icon: Icons.flag_outlined,
                title: '举报说明',
                destination: _SettingsPageDestination.reportGuidelines,
              ),
            ],
          ),
        ],
      ),
      _ => const _SettingsDetailContent(
        title: '界面与主题',
        sections: <_SettingsDetailSection>[
          _SettingsDetailSection(
            title: '显示与主题',
            items: <_SettingsDetailItem>[
              _SettingsDetailItem(
                icon: Icons.brightness_auto_outlined,
                title: '界面主题',
                destination: _SettingsPageDestination.themeMode,
              ),
              _SettingsDetailItem(
                icon: Icons.palette_outlined,
                title: '主题方案',
                destination: _SettingsPageDestination.preset,
              ),
            ],
          ),
        ],
      ),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxxl,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text(
              content.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xxl),
            for (final _SettingsDetailSection section
                in content.sections) ...<Widget>[
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsGroup(items: section.items),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});

  final List<_SettingsDetailItem> items;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Column(
      children: <Widget>[
        for (int index = 0; index < items.length; index++) ...<Widget>[
          _SettingsDetailRow(item: items[index]),
          if (index != items.length - 1)
            Divider(height: 1, indent: 64, color: colors.line),
        ],
      ],
    );
  }
}

class _SettingsDetailRow extends StatelessWidget {
  const _SettingsDetailRow({required this.item});

  final _SettingsDetailItem item;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String? subtitle = switch (item.destination) {
      _SettingsPageDestination.themeMode => _themeModeLabel(
        WebThemeStore.instance.themeMode,
      ),
      _SettingsPageDestination.preset => WebThemeStore.instance.preset.label,
      _SettingsPageDestination.locale => _localeLabel(
        AppLocaleStore.instance.locale,
      ),
      _ => item.subtitle,
    };
    return Material(
      color: colors.page.withValues(alpha: 0),
      child: InkWell(
        onTap: () => _openDestination(context, item.destination),
        borderRadius: BorderRadius.circular(AppRadii.hero),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(item.icon, size: 20, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.faintInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDestination {
  const _SettingsDestination({
    required this.id,
    required this.section,
    required this.icon,
    required this.label,
    required this.keywords,
  });

  final String id;
  final String section;
  final IconData icon;
  final String label;
  final String keywords;
}

class _SettingsDetailContent {
  const _SettingsDetailContent({required this.title, required this.sections});

  final String title;
  final List<_SettingsDetailSection> sections;
}

class _SettingsDetailSection {
  const _SettingsDetailSection({required this.title, required this.items});

  final String title;
  final List<_SettingsDetailItem> items;
}

class _SettingsDetailItem {
  const _SettingsDetailItem({
    required this.icon,
    required this.title,
    required this.destination,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final _SettingsPageDestination destination;
}

enum _SettingsPageDestination {
  themeMode,
  preset,
  locale,
  emoji,
  terms,
  privacy,
  guidelines,
  reportGuidelines,
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统设置',
  ThemeMode.light => '浅色模式',
  ThemeMode.dark => '深色模式',
};

Future<void> _openDestination(
  BuildContext context,
  _SettingsPageDestination destination,
) async {
  switch (destination) {
    case _SettingsPageDestination.themeMode:
      _openAppearanceDialog(context);
      return;
    case _SettingsPageDestination.preset:
      _openPresetDialog(context);
      return;
    case _SettingsPageDestination.locale:
      _openLocaleDialog(context);
      return;
    case _SettingsPageDestination.emoji:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const EmojiSettingsPage()),
      );
      return;
    case _SettingsPageDestination.terms:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TermsOfServicePage()),
      );
      return;
    case _SettingsPageDestination.privacy:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
      );
      return;
    case _SettingsPageDestination.guidelines:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CommunityGuidelinesPage(),
        ),
      );
      return;
    case _SettingsPageDestination.reportGuidelines:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReportGuidelinesPage()),
      );
      return;
  }
}

String _localeLabel(Locale locale) =>
    locale.languageCode == 'en' ? 'English' : '简体中文';

void _openLocaleDialog(BuildContext context) {
  final AppLocaleStore store = AppLocaleStore.instance;
  showAppDialog<void>(
    context: context,
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
            Text('应用语言', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<Locale>(
              groupValue: store.locale,
              onChanged: (Locale? next) async {
                if (next == null) return;
                await store.setLocale(next);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Column(
                children: <Widget>[
                  RadioListTile<Locale>(
                    value: Locale('zh', 'CN'),
                    title: Text('简体中文'),
                  ),
                  RadioListTile<Locale>(
                    value: Locale('en'),
                    title: Text('English'),
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

void _openAppearanceDialog(BuildContext context) {
  final WebThemeStore store = WebThemeStore.instance;
  showAppDialog<void>(
    context: context,
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

void _openPresetDialog(BuildContext context) {
  final WebThemeStore store = WebThemeStore.instance;
  showAppDialog<void>(
    context: context,
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
