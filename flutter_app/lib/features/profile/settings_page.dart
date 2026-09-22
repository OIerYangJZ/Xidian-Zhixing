import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/state/app_theme_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
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
  int _selected = 2;

  static const List<_SettingsItem> _items = <_SettingsItem>[
    _SettingsItem(
      icon: Icons.person_outline,
      zh: '账户中心',
      en: 'Accounts Center',
      subtitleZh: '密码、安全、个人资料、关联体验、广告偏好',
      subtitleEn: 'Password, security, personal details, connected experiences, ad preferences',
    ),
    _SettingsItem(
      icon: Icons.person_outline,
      zh: '青少年账户监管',
      en: 'Supervision for Teen Accounts',
    ),
    _SettingsItem(icon: Icons.lock_outline, zh: '隐私', en: 'Privacy'),
    _SettingsItem(
      icon: Icons.tune,
      zh: '内容偏好',
      en: 'Content preferences',
    ),
    _SettingsItem(
      icon: Icons.person_outline,
      zh: '账户状态',
      en: 'Account status',
    ),
    _SettingsItem(
      icon: Icons.tune,
      zh: '更多设置',
      en: 'More settings',
    ),
    _SettingsItem(icon: Icons.help_outline, zh: '帮助', en: 'Help'),
  ];

  @override
  Widget build(BuildContext context) {
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double scale = desktop
        ? AppLayout.shellScale(MediaQuery.sizeOf(context).width)
        : 1;
    final EditorialColors colors = EditorialColors.of(context);
    final Locale locale = Localizations.localeOf(context);
    final Widget panel = Container(
      width: desktop ? 1214 * scale : double.infinity,
      constraints: BoxConstraints(minHeight: desktop ? 1148 * scale : 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: desktop ? Border.all(color: colors.line) : null,
        borderRadius: desktop
            ? BorderRadius.vertical(top: Radius.circular(34 * scale))
            : BorderRadius.zero,
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 421 * scale,
                  child: _SettingsNavigation(
                    items: _items,
                    selected: _selected,
                    scale: scale,
                    locale: locale,
                    onSelected: (int value) =>
                        setState(() => _selected = value),
                  ),
                ),
                Expanded(
                  child: _SettingsContent(
                    items: _items,
                    selected: _selected,
                    scale: scale,
                    locale: locale,
                  ),
                ),
              ],
            )
          : _SettingsMobileContent(locale: locale),
    );

    return Scaffold(
      backgroundColor: colors.page,
      body: desktop
          ? Column(
              children: <Widget>[
                SizedBox(height: 100 * scale),
                panel,
              ],
            )
          : panel,
    );
  }
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.items,
    required this.selected,
    required this.scale,
    required this.locale,
    required this.onSelected,
  });

  final List<_SettingsItem> items;
  final int selected;
  final double scale;
  final Locale locale;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16 * scale, 20 * scale, 16 * scale, 0),
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
              locale: locale,
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
    required this.locale,
    required this.onTap,
  });

  final _SettingsItem item;
  final bool selected;
  final double scale;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String? subtitle = item.subtitleFor(locale);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 66 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 17 * scale,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.apricot : Colors.transparent,
            borderRadius: BorderRadius.circular(18 * scale),
          ),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              Icon(item.icon, size: 32 * scale, color: colors.ink),
              SizedBox(width: 18 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.titleFor(locale),
                      style: TextStyle(
                        fontSize: 22 * scale,
                        height: 1.32,
                        color: colors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4 * scale),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 20 * scale,
                            height: 1.25,
                            color: colors.mutedInk,
                          ),
                        ),
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
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.items,
    required this.selected,
    required this.scale,
    required this.locale,
  });

  final List<_SettingsItem> items;
  final int selected;
  final double scale;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final List<_SettingsRowData> rows = switch (selected) {
      0 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '账号与安全',
            en: 'Password and security',
            icon: Icons.lock_outline,
          ),
          _SettingsRowData(
            zh: '个人资料',
            en: 'Personal details',
            icon: Icons.person_outline,
          ),
          _SettingsRowData(
            zh: '校园系统登录',
            en: 'Campus system sign-in',
            icon: Icons.key_outlined,
            page: const CampusAuthCenterPage(),
          ),
        ],
      1 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '青少年账户监管',
            en: 'Supervision for Teen Accounts',
            icon: Icons.person_outline,
          ),
        ],
      2 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '私密账户',
            en: 'Private profile',
            icon: Icons.lock_outline,
            valueZh: '公开',
            valueEn: 'Public',
          ),
          _SettingsRowData(
            zh: '标签和提及',
            en: 'Tags and mentions',
            icon: Icons.person_outline,
          ),
          _SettingsRowData(
            zh: '在线状态',
            en: 'Online status',
            icon: Icons.person_outline,
          ),
          _SettingsRowData(
            zh: '消息',
            en: 'Messages',
            icon: Icons.send_outlined,
          ),
          _SettingsRowData(
            zh: '受限账户',
            en: 'Restricted profiles',
            icon: Icons.person_outline,
          ),
          _SettingsRowData(
            zh: '已屏蔽账户',
            en: 'Blocked profiles',
            icon: Icons.block_outlined,
          ),
          _SettingsRowData(
            zh: '私密点赞',
            en: 'Private likes',
            icon: Icons.favorite_border,
          ),
        ],
      3 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '推荐内容',
            en: 'Recommended content',
            icon: Icons.tune,
          ),
          _SettingsRowData(
            zh: '屏蔽的词语',
            en: 'Muted words',
            icon: Icons.tune,
          ),
        ],
      4 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '账户状态',
            en: 'Account status',
            icon: Icons.person_outline,
          ),
        ],
      5 => <_SettingsRowData>[
          _SettingsRowData(
            zh: '显示模式',
            en: 'Display mode',
            icon: Icons.dark_mode_outlined,
            trailing: _DisplayModeSwitch(scale: scale),
          ),
          _SettingsRowData(
            zh: '配色主题',
            en: 'Color theme',
            icon: Icons.palette_outlined,
            trailing: _CompactThemeControl(scale: scale),
          ),
          _SettingsRowData(
            zh: '表情与输入',
            en: 'Emoji and input',
            icon: Icons.emoji_emotions_outlined,
            page: const EmojiSettingsPage(),
          ),
          _SettingsRowData(
            zh: '用户协议',
            en: 'Terms of Service',
            icon: Icons.description_outlined,
            page: const TermsOfServicePage(),
          ),
          _SettingsRowData(
            zh: '隐私政策',
            en: 'Privacy Policy',
            icon: Icons.shield_outlined,
            page: const PrivacyPolicyPage(),
          ),
          _SettingsRowData(
            zh: '社区规范',
            en: 'Community Guidelines',
            icon: Icons.groups_outlined,
            page: const CommunityGuidelinesPage(),
          ),
          _SettingsRowData(
            zh: '举报说明',
            en: 'Reporting Guidelines',
            icon: Icons.flag_outlined,
            page: const ReportGuidelinesPage(),
          ),
        ],
      _ => <_SettingsRowData>[],
    };

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
            _SettingsRow(row: row, scale: scale, locale: locale),
          _LanguageRow(scale: scale, locale: locale),
        ],
      ),
    );
  }
}

class _SettingsMobileContent extends StatelessWidget {
  const _SettingsMobileContent({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Column(
      children: <Widget>[
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(
                  '‹',
                  style: TextStyle(fontSize: 32, color: colors.ink, height: 1),
                ),
              ),
              Text(
                uiText(context, zh: '隐私', en: 'Privacy'),
                style: TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  color: colors.ink,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: _SettingsContent(
              items: _SettingsPageState._items,
              selected: 2,
              scale: 1,
              locale: locale,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.row,
    required this.scale,
    required this.locale,
  });

  final _SettingsRowData row;
  final double scale;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String? value = row.valueFor(locale);
    final Widget trailing = row.trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != null)
              Padding(
                padding: EdgeInsets.only(right: 18 * scale),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    height: 1.3,
                    color: colors.mutedInk,
                  ),
                ),
              ),
            if (row.page != null || value == null)
              Text(
                '›',
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 32 * scale,
                  height: 1,
                  color: colors.mutedInk,
                ),
              ),
          ],
        );

    return InkWell(
      onTap: row.page == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => row.page!),
              ),
      child: SizedBox(
        width: double.infinity,
        height: 67 * scale,
        child: Row(
          children: <Widget>[
            Icon(row.icon, size: 32 * scale, color: colors.ink),
            SizedBox(width: 19 * scale),
            Expanded(
              child: Text(
                row.titleFor(locale),
                style: TextStyle(
                  fontSize: 22 * scale,
                  height: 1.32,
                  color: colors.ink,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.scale, required this.locale});

  final double scale;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      margin: EdgeInsets.only(top: 20 * scale),
      padding: EdgeInsets.symmetric(vertical: 22 * scale),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              uiText(context, zh: '语言', en: 'Language'),
              style: TextStyle(
                fontSize: 22 * scale,
                height: 1.32,
                color: colors.ink,
              ),
            ),
          ),
          _LanguageSelect(locale: locale, scale: scale),
        ],
      ),
    );
  }
}

class _LanguageSelect extends StatelessWidget {
  const _LanguageSelect({required this.locale, required this.scale});

  final Locale locale;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      width: 126 * scale,
      height: 44 * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          isExpanded: true,
          isDense: true,
          value: locale.languageCode == 'en'
              ? const Locale('en')
              : const Locale('zh', 'CN'),
          icon: Icon(Icons.keyboard_arrow_down, size: 20 * scale),
          style: TextStyle(
            fontSize: 18 * scale,
            color: colors.ink,
            fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
          ),
          items: const <DropdownMenuItem<Locale>>[
            DropdownMenuItem(value: Locale('zh', 'CN'), child: Text('简体中文')),
            DropdownMenuItem(value: Locale('en'), child: Text('English')),
          ],
          onChanged: (Locale? value) {
            if (value != null) AppLocaleStore.instance.setLocale(value);
          },
        ),
      ),
    );
  }
}

class _DisplayModeSwitch extends StatelessWidget {
  const _DisplayModeSwitch({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeStore.instance,
      builder: (BuildContext context, Widget? child) => Switch(
        value: AppThemeStore.instance.mode == ThemeMode.dark,
        onChanged: (bool value) => AppThemeStore.instance.setMode(
          value ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}

class _CompactThemeControl extends StatelessWidget {
  const _CompactThemeControl({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeStore.instance,
      builder: (BuildContext context, Widget? child) => DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: AppThemeStore.instance.themeKey,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: AppColorThemes.options
              .map(
                (AppColorThemeOption option) => DropdownMenuItem<String>(
                  value: option.key,
                  child: Text(option.labelFor(Localizations.localeOf(context))),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value != null) AppThemeStore.instance.setThemeKey(value);
          },
        ),
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.zh,
    required this.en,
    this.subtitleZh,
    this.subtitleEn,
  });

  final IconData icon;
  final String zh;
  final String en;
  final String? subtitleZh;
  final String? subtitleEn;

  String titleFor(Locale locale) => locale.languageCode == 'en' ? en : zh;

  String? subtitleFor(Locale locale) =>
      locale.languageCode == 'en' ? subtitleEn : subtitleZh;
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.zh,
    required this.en,
    required this.icon,
    this.valueZh,
    this.valueEn,
    this.trailing,
    this.page,
  });

  final String zh;
  final String en;
  final IconData icon;
  final String? valueZh;
  final String? valueEn;
  final Widget? trailing;
  final Widget? page;

  String titleFor(Locale locale) => locale.languageCode == 'en' ? en : zh;

  String? valueFor(Locale locale) =>
      locale.languageCode == 'en' ? valueEn : valueZh;
}
