import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../campus/campus_auth_center_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<_SettingsItem> _items = <_SettingsItem>[
    _SettingsItem('账号与安全', 'Account and security'),
    _SettingsItem('隐私', 'Privacy'),
    _SettingsItem('通知设置', 'Notification settings'),
    _SettingsItem('界面外观', 'Appearance'),
    _SettingsItem('关于与支持', 'About and support'),
  ];

  int _selected = 0;

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
                    scale: scale,
                    locale: locale,
                    selected: _selected,
                    onSelected: (int index) =>
                        setState(() => _selected = index),
                  ),
                ),
                Expanded(
                  child: _SettingsContent(
                    selected: _selected,
                    scale: scale,
                    locale: locale,
                  ),
                ),
              ],
            )
          : _MobileSettingsContent(locale: locale),
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
    required this.scale,
    required this.locale,
    required this.selected,
    required this.onSelected,
  });

  final List<_SettingsItem> items;
  final double scale;
  final Locale locale;
  final int selected;
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
            _SettingsNavigationRow(
              item: items[index],
              scale: scale,
              locale: locale,
              // The reference settings index has no selected fill.
              selected: false,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavigationRow extends StatelessWidget {
  const _SettingsNavigationRow({
    required this.item,
    required this.scale,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final _SettingsItem item;
  final double scale;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
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
          children: <Widget>[
            Text(
              '›',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 32 * scale,
                height: 0.9,
                color: colors.mutedInk,
              ),
            ),
            SizedBox(width: 18 * scale),
            Expanded(
              child: Text(
                item.titleFor(locale),
                style: TextStyle(
                  fontSize: 22 * scale,
                  height: 1.32,
                  color: colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.selected,
    required this.scale,
    required this.locale,
  });

  final int selected;
  final double scale;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final List<_SettingsOption> options = _optionsFor(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        20 * scale,
        33 * scale,
        30 * scale,
      ),
      child: Column(
        children: <Widget>[
          for (final _SettingsOption option in options)
            _SettingsOptionRow(option: option, scale: scale, locale: locale),
          if (selected == 3) _LanguageRow(scale: scale, locale: locale),
        ],
      ),
    );
  }

  List<_SettingsOption> _optionsFor(BuildContext context) {
    switch (selected) {
      case 0:
        return <_SettingsOption>[
          _SettingsOption(
            '校园系统登录',
            'Campus system sign-in',
            icon: Icons.key_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CampusAuthCenterPage(),
              ),
            ),
          ),
          _SettingsOption('账号认证', 'Account verification'),
          _SettingsOption('注销账号', 'Delete account'),
        ];
      case 1:
        return <_SettingsOption>[
          _SettingsOption('允许接收私信', 'Allow direct messages'),
          _SettingsOption('公开关注列表', 'Public following list'),
          _SettingsOption('显示在线状态', 'Show online status'),
          _SettingsOption('已屏蔽用户', 'Blocked profiles'),
        ];
      case 2:
        return <_SettingsOption>[
          _SettingsOption('回复与评论', 'Replies and comments'),
          _SettingsOption('提及我的', 'Mentions'),
          _SettingsOption('点赞', 'Likes'),
          _SettingsOption('新增关注', 'New followers'),
          _SettingsOption('私信', 'Direct messages'),
        ];
      case 3:
        return <_SettingsOption>[_SettingsOption('深色模式', 'Dark mode')];
      case 4:
        return <_SettingsOption>[
          _SettingsOption('用户协议', 'Terms of Service'),
          _SettingsOption('隐私政策', 'Privacy Policy'),
          _SettingsOption('社区规范', 'Community Guidelines'),
          _SettingsOption('举报说明', 'Reporting Guidelines'),
        ];
      default:
        return <_SettingsOption>[];
    }
  }
}

class _SettingsOptionRow extends StatelessWidget {
  const _SettingsOptionRow({
    required this.option,
    required this.scale,
    required this.locale,
  });

  final _SettingsOption option;
  final double scale;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
      onTap: option.onTap,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 68 * scale),
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              Icon(option.icon, size: 25 * scale, color: colors.ink),
              SizedBox(width: 18 * scale),
            ],
            Expanded(
              child: Text(
                option.titleFor(locale),
                style: TextStyle(
                  fontSize: 22 * scale,
                  height: 1.32,
                  color: colors.ink,
                ),
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 32 * scale,
                height: 0.9,
                color: colors.mutedInk,
              ),
            ),
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
          value: locale.languageCode == 'en'
              ? const Locale('en')
              : const Locale('zh', 'CN'),
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 20 * scale),
          style: TextStyle(
            fontSize: 18 * scale,
            color: colors.ink,
            fontFamily: 'Arial',
            fontFamilyFallback: const <String>['STZhongsong', '华文中宋', 'serif'],
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

class _MobileSettingsContent extends StatelessWidget {
  const _MobileSettingsContent({required this.locale});

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
          alignment: Alignment.centerLeft,
          child: Text(
            uiText(context, zh: '设置', en: 'Settings'),
            style: TextStyle(fontSize: 22, height: 1.2, color: colors.ink),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 24),
            child: Column(
              children: <Widget>[
                for (final _SettingsItem item in _SettingsPageState._items)
                  _MobileSettingsRow(title: item.titleFor(locale)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileSettingsRow extends StatelessWidget {
  const _MobileSettingsRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
      onTap: () {},
      child: SizedBox(
        width: double.infinity,
        height: 63,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.32,
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 25,
                  height: 0.9,
                  color: colors.mutedInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsOption {
  const _SettingsOption(this.zh, this.en, {this.icon, this.onTap});

  final String zh;
  final String en;
  final IconData? icon;
  final VoidCallback? onTap;

  String titleFor(Locale locale) => locale.languageCode == 'en' ? en : zh;
}

class _SettingsItem {
  const _SettingsItem(this.zh, this.en);

  final String zh;
  final String en;

  String titleFor(Locale locale) => locale.languageCode == 'en' ? en : zh;
}
