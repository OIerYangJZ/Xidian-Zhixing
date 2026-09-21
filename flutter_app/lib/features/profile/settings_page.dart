import 'package:flutter/material.dart';

import '../../core/state/app_locale_store.dart';
import '../../core/state/app_theme_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/theme_dropdown.dart';
import '../campus/campus_auth_center_page.dart';
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
  int _selected = 1;

  static const List<_SettingsItem> _items = <_SettingsItem>[
    _SettingsItem('账号与安全', Icons.person_outline),
    _SettingsItem('隐私', Icons.lock_outline),
    _SettingsItem('通知设置', Icons.notifications_none),
    _SettingsItem('界面外观', Icons.tune),
    _SettingsItem('AI 设置', Icons.auto_awesome_outlined),
    _SettingsItem('关于与支持', Icons.help_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double scale = desktop
        ? AppLayout.shellScale(MediaQuery.sizeOf(context).width)
        : 1;
    final EditorialColors colors = EditorialColors.of(context);
    final Widget panel = Container(
      width: desktop ? 1214 * scale : double.infinity,
      height: desktop ? 1148 * scale : null,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: desktop
            ? BorderRadius.vertical(top: Radius.circular(34 * scale))
            : BorderRadius.zero,
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 421 * scale,
                  child: _SettingsNavigation(
                    items: _items,
                    selected: _selected,
                    scale: scale,
                    onSelected: (int value) =>
                        setState(() => _selected = value),
                  ),
                ),
                Expanded(
                  child: _SettingsContent(
                    items: _items,
                    selected: _selected,
                    scale: scale,
                  ),
                ),
              ],
            )
          : _SettingsContent(items: _items, selected: _selected, scale: 1),
    );

    return Scaffold(
      backgroundColor: colors.page,
      body: Container(
        color: colors.page,
        child: desktop
            ? Column(
                children: <Widget>[
                  SizedBox(height: 100 * scale),
                  panel,
                ],
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  panel,
                ],
              ),
      ),
    );
  }
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.items,
    required this.selected,
    required this.scale,
    required this.onSelected,
  });

  final List<_SettingsItem> items;
  final int selected;
  final double scale;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < items.length; index++)
            _SettingsNavRow(
              item: items[index],
              selected: index == selected,
              scale: scale,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.item,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  final _SettingsItem item;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: Container(
          constraints: BoxConstraints(minHeight: 66 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 17 * scale,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(18 * scale),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.chevron_right,
                size: 22 * scale,
                color: colors.mutedInk,
              ),
              SizedBox(width: 18 * scale),
              Icon(item.icon, size: 26 * scale, color: colors.ink),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 20 * scale,
                    height: 1.25,
                    color: colors.ink,
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

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.items,
    required this.selected,
    required this.scale,
  });

  final List<_SettingsItem> items;
  final int selected;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final bool appearance = selected == 3;
    final bool about = selected == 5;
    final List<_SettingsRowData> rows = appearance
        ? <_SettingsRowData>[
            _SettingsRowData(
              '语言',
              trailing: LanguageToggle(
                locale: Localizations.localeOf(context),
                compact: true,
                onChanged: AppLocaleStore.instance.setLocale,
              ),
            ),
            _SettingsRowData(
              '显示模式',
              trailing: ListenableBuilder(
                listenable: AppThemeStore.instance,
                builder: (BuildContext context, Widget? child) => Switch(
                  value: AppThemeStore.instance.mode == ThemeMode.dark,
                  onChanged: (bool value) => AppThemeStore.instance.setMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              ),
            ),
            _SettingsRowData(
              '配色主题',
              trailing: ListenableBuilder(
                listenable: AppThemeStore.instance,
                builder: (BuildContext context, Widget? child) => ThemeDropdown(
                  themeKey: AppThemeStore.instance.themeKey,
                  locale: Localizations.localeOf(context),
                  compact: true,
                  onChanged: AppThemeStore.instance.setThemeKey,
                ),
              ),
            ),
            const _SettingsRowData('表情与输入'),
          ]
        : about
        ? <_SettingsRowData>[
            _SettingsRowData('用户协议', page: const TermsOfServicePage()),
            _SettingsRowData('隐私政策', page: const PrivacyPolicyPage()),
            _SettingsRowData('社区规范', page: const CommunityGuidelinesPage()),
            _SettingsRowData('举报说明', page: const ReportGuidelinesPage()),
          ]
        : <_SettingsRowData>[
            for (final _SettingsItem item in items)
              _SettingsRowData(item.label),
          ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        20 * scale,
        33 * scale,
        30 * scale,
      ),
      child: Column(
        children: <Widget>[
          for (final _SettingsRowData row in rows)
            _SettingsRow(row: row, scale: scale),
          if (!appearance && !about) ...<Widget>[
            SizedBox(height: 20 * scale),
            _SettingsRow(
              row: _SettingsRowData(
                '语言',
                trailing: LanguageToggle(
                  locale: Localizations.localeOf(context),
                  compact: true,
                  onChanged: AppLocaleStore.instance.setLocale,
                ),
              ),
              scale: scale,
            ),
            _SettingsRow(
              row: _SettingsRowData(
                '校园系统登录',
                leading: Icons.key_outlined,
                page: const CampusAuthCenterPage(),
              ),
              scale: scale,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.row, required this.scale});

  final _SettingsRowData row;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.page == null && row.trailing == null
            ? null
            : () {
                if (row.page != null) {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => row.page!));
                }
                if (row.label == '表情与输入') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmojiSettingsPage(),
                    ),
                  );
                }
              },
        child: Container(
          constraints: BoxConstraints(minHeight: 67 * scale),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: <Widget>[
              if (row.leading != null) ...<Widget>[
                Icon(row.leading, size: 32 * scale, color: colors.ink),
                SizedBox(width: 19 * scale),
              ],
              Expanded(
                child: Text(
                  row.label,
                  style: TextStyle(
                    fontSize: 22 * scale,
                    height: 1.35,
                    color: colors.ink,
                  ),
                ),
              ),
              if (row.trailing != null)
                row.trailing!
              else
                Icon(
                  Icons.chevron_right,
                  size: 28 * scale,
                  color: colors.mutedInk,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _SettingsRowData {
  const _SettingsRowData(this.label, {this.leading, this.trailing, this.page});

  final String label;
  final IconData? leading;
  final Widget? trailing;
  final Widget? page;
}
