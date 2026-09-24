import 'package:flutter/material.dart';

import '../core/auth/auth_store.dart';
import '../core/l10n/ui_text.dart';
import '../design_system/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_profile.dart';

/// Home shell for every width (handoff W1 / W2 / W4 / W5):
///
/// * ≥ 1200: sidebar with brand, 树洞 · 校园 · 校园 AI, 发布心声, then
///   搜索 · 通知 · 会话 · 设置 and the profile block.
/// * 960–1199: the same sidebar as an icon rail.
/// * < 960: top bar (the avatar opens the profile menu, so every entry stays
///   reachable), bottom bar with the three sections, and a 发布 button.
class DiscussionHomeScaffold extends StatelessWidget {
  const DiscussionHomeScaffold({
    super.key,
    required this.currentIndex,
    required this.content,
    required this.notificationUnreadCount,
    this.messageUnreadCount = 0,
    required this.onSelect,
    required this.onCreate,
    required this.onFilter,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onSettings,
    required this.onProfile,
  });

  final int currentIndex;
  final Widget content;
  final int notificationUnreadCount;
  final int messageUnreadCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onFilter;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  /// Opens the profile menu (个人资料与设置, 我的帖子, …, 语言, 退出登录).
  final VoidCallback onProfile;

  static const double sidebarBreakpoint = 960;
  static const double expandedBreakpoint = 1200;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<_Section> sections = <_Section>[
      _Section(l10n.treehole, Icons.forum_outlined, Icons.forum_rounded),
      _Section(
        l10n.campus,
        Icons.account_balance_outlined,
        Icons.account_balance_rounded,
      ),
      _Section(l10n.campusAi, Icons.auto_awesome_outlined, Icons.auto_awesome),
    ];
    final double width = MediaQuery.sizeOf(context).width;

    if (width >= sidebarBreakpoint) {
      return Scaffold(
        key: const Key('discussion-ui-shell'),
        body: ZxPaper(
          child: Row(
            children: <Widget>[
              _Sidebar(
                expanded: width >= expandedBreakpoint,
                sections: sections,
                currentIndex: currentIndex,
                notificationUnreadCount: notificationUnreadCount,
                messageUnreadCount: messageUnreadCount,
                onSelect: onSelect,
                onCreate: onCreate,
                onSearch: onSearch,
                onNotifications: onNotifications,
                onMessages: onMessages,
                onSettings: onSettings,
                onProfile: onProfile,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      key: const Key('discussion-ui-shell'),
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ZxGlass(
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  _ProfileAvatar(
                    key: const Key('shell-profile-entry'),
                    size: 34,
                    onTap: onProfile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sections[currentIndex].label,
                      style: ZxType.headline.copyWith(
                        fontSize: 20,
                        height: 1.2,
                        color: t.text,
                      ),
                    ),
                  ),
                  if (currentIndex == 0)
                    IconButton(
                      tooltip: l10n.filter,
                      onPressed: onFilter,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  IconButton(
                    tooltip: l10n.search,
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  _BadgedIconButton(
                    tooltip: l10n.notifications,
                    icon: Icons.notifications_none_rounded,
                    count: notificationUnreadCount,
                    onPressed: onNotifications,
                  ),
                  _BadgedIconButton(
                    tooltip: l10n.conversations,
                    icon: Icons.chat_bubble_outline_rounded,
                    count: messageUnreadCount,
                    onPressed: onMessages,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ZxPaper(child: content),
      floatingActionButton: currentIndex == 0
          ? _CreateButton(
              key: const Key('create-post-fab'),
              label: width >= 600 ? l10n.createPost : null,
              onPressed: onCreate,
            )
          : null,
      bottomNavigationBar: _BottomBar(
        key: const Key('mobile-primary-navigation'),
        sections: sections,
        currentIndex: currentIndex,
        onSelect: onSelect,
      ),
    );
  }
}

class _Section {
  const _Section(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.expanded,
    required this.sections,
    required this.currentIndex,
    required this.notificationUnreadCount,
    required this.messageUnreadCount,
    required this.onSelect,
    required this.onCreate,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onSettings,
    required this.onProfile,
  });

  final bool expanded;
  final List<_Section> sections;
  final int currentIndex;
  final int notificationUnreadCount;
  final int messageUnreadCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('desktop-primary-navigation'),
      width: expanded ? 248 : 76,
      padding: EdgeInsets.fromLTRB(
        expanded ? 14 : 12,
        20,
        expanded ? 14 : 12,
        14,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Brand(expanded: expanded, onTap: () => onSelect(0)),
          const SizedBox(height: 24),
          for (int i = 0; i < sections.length; i++)
            _NavItem(
              icon: currentIndex == i
                  ? sections[i].selectedIcon
                  : sections[i].icon,
              label: sections[i].label,
              selected: currentIndex == i,
              expanded: expanded,
              onTap: () => onSelect(i),
            ),
          const SizedBox(height: 14),
          if (expanded)
            ZxButton(
              key: const Key('create-post-top-action'),
              label: l10n.publishVoice,
              icon: Icons.edit_outlined,
              expand: true,
              onPressed: onCreate,
            )
          else
            Center(
              child: _CreateButton(
                key: const Key('create-post-top-action'),
                onPressed: onCreate,
              ),
            ),
          const SizedBox(height: 18),
          _NavItem(
            icon: Icons.search_rounded,
            label: l10n.search,
            expanded: expanded,
            onTap: onSearch,
          ),
          _NavItem(
            icon: Icons.notifications_none_rounded,
            label: l10n.notifications,
            badge: notificationUnreadCount,
            expanded: expanded,
            onTap: onNotifications,
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.conversations,
            badge: messageUnreadCount,
            expanded: expanded,
            onTap: onMessages,
          ),
          _NavItem(
            icon: Icons.tune_rounded,
            label: l10n.settings,
            expanded: expanded,
            onTap: onSettings,
          ),
          const Spacer(),
          _ProfileBlock(expanded: expanded, onTap: onProfile),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget seal = const ZxAvatar.anonymous(name: '知', size: 38);
    return InkWell(
      onTap: onTap,
      borderRadius: ZxRadius.buttonAll,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: expanded
            ? Row(
                children: <Widget>[
                  seal,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          uiText(context, zh: '西电知行', en: 'Xidian Zhixing'),
                          style: ZxType.headline.copyWith(
                            fontSize: 19,
                            height: 1.2,
                            color: t.text,
                          ),
                        ),
                        Text(
                          'XIDIAN ZHIXING',
                          style: ZxType.micro.copyWith(
                            color: t.text3,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(child: seal),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color color = selected ? t.primary : t.text2;
    final Widget iconWidget = Badge(
      isLabelVisible: !expanded && badge > 0,
      smallSize: 8,
      child: Icon(icon, size: 21, color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: selected ? t.primarySoft : Colors.transparent,
          borderRadius: ZxRadius.buttonAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: ZxRadius.buttonAll,
            child: SizedBox(
              height: 44,
              child: expanded
                  ? Row(
                      children: <Widget>[
                        const SizedBox(width: 12),
                        iconWidget,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: ZxType.body.copyWith(
                              color: color,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (badge > 0) ...<Widget>[
                          ZxCountBadge(badge),
                          const SizedBox(width: 10),
                        ],
                      ],
                    )
                  : Center(child: iconWidget),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final UserProfile? user = AuthStore.instance.currentUser;
    final String nickname = user?.nickname.trim() ?? '';
    if (!expanded) {
      return Center(child: _ProfileAvatar(size: 40, onTap: onTap));
    }
    return Material(
      key: const Key('shell-profile-entry'),
      color: t.bg,
      borderRadius: ZxRadius.cardAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZxRadius.cardAll,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              const _ProfileAvatar(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      nickname.isEmpty ? l10n.personalCenter : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZxType.label.copyWith(color: t.text),
                    ),
                    Text(
                      l10n.profileAndSettings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signed-in user's avatar. Tapping it opens the profile menu.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({super.key, required this.size, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UserProfile? user = AuthStore.instance.currentUser;
    final String nickname = user?.nickname.trim() ?? '';
    return Semantics(
      label: uiText(context, zh: '个人资料与设置', en: 'Profile and settings'),
      button: onTap != null,
      child: ZxAvatar(
        name: nickname.isEmpty ? uiText(context, zh: '我', en: 'Me') : nickname,
        imageUrl: user?.avatarUrl,
        size: size,
        onTap: onTap,
      ),
    );
  }
}

class _BadgedIconButton extends StatelessWidget {
  const _BadgedIconButton({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(icon),
      ),
    );
  }
}

/// 发布: square with the primary glow; with [label] it widens into a pill.
class _CreateButton extends StatelessWidget {
  const _CreateButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final String tooltip = AppLocalizations.of(context)!.createPost;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: label == null ? ZxRadius.cardAll : ZxRadius.pillAll,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(t.primary, t.surface, 0.1)!,
              t.primaryPressed,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: t.primaryGlow,
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: label == null ? ZxRadius.cardAll : ZxRadius.pillAll,
            child: SizedBox(
              height: ZxSize.fab - 4,
              width: label == null ? ZxSize.fab - 4 : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: label == null ? 0 : 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.edit_outlined, color: t.onPrimary, size: 21),
                    if (label != null) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        label!,
                        style: ZxType.label.copyWith(color: t.onPrimary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    super.key,
    required this.sections,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Section> sections;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return ZxGlass(
      border: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < sections.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            currentIndex == i
                                ? sections[i].selectedIcon
                                : sections[i].icon,
                            size: 23,
                            color: currentIndex == i ? t.primary : t.text3,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sections[i].label,
                            style: ZxType.micro.copyWith(
                              color: currentIndex == i ? t.primary : t.text3,
                              fontWeight: currentIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
