import 'package:flutter/material.dart';

import '../core/auth/auth_store.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../core/widgets/app_surfaces.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/l10n/ui_text.dart';

class DiscussionHomeScaffold extends StatelessWidget {
  const DiscussionHomeScaffold({
    super.key,
    required this.currentIndex,
    required this.content,
    required this.notificationUnreadCount,
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
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onFilter;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final bool desktop = AppBreakpoints.isDesktop(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<_DiscussionDestination> destinations = <_DiscussionDestination>[
      _DiscussionDestination(l10n.treehole, Icons.forum_outlined),
      _DiscussionDestination(l10n.campus, Icons.account_balance_outlined),
      _DiscussionDestination(l10n.campusAi, Icons.auto_awesome_outlined),
    ];

    return Scaffold(
      key: const Key('discussion-ui-shell'),
      backgroundColor: EditorialColors.of(context).page,
      appBar: desktop
          ? null
          : AppBar(
              titleSpacing: AppSpacing.md,
              title: const SizedBox.shrink(),
              actions: <Widget>[
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
                IconButton(
                  tooltip: l10n.notifications,
                  onPressed: onNotifications,
                  icon: Badge(
                    isLabelVisible: notificationUnreadCount > 0,
                    label: Text(
                      notificationUnreadCount > 99
                          ? '99+'
                          : '$notificationUnreadCount',
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                IconButton(
                  tooltip: l10n.conversations,
                  onPressed: onMessages,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                IconButton(
                  tooltip: l10n.settings,
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
      body: desktop
          ? Row(
              children: <Widget>[
                _DiscussionRail(
                  currentIndex: currentIndex,
                  destinations: destinations,
                  notificationUnreadCount: notificationUnreadCount,
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
            )
          : content,
      floatingActionButton: !desktop && currentIndex == 0
          ? FloatingActionButton(
              key: const Key('create-post-fab'),
              onPressed: onCreate,
              tooltip: l10n.createPost,
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              key: const Key('mobile-primary-navigation'),
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              destinations: destinations
                  .map(
                    (_DiscussionDestination item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _DiscussionRail extends StatelessWidget {
  const _DiscussionRail({
    required this.currentIndex,
    required this.destinations,
    required this.notificationUnreadCount,
    required this.onSelect,
    required this.onCreate,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onSettings,
    required this.onProfile,
  });

  final int currentIndex;
  final List<_DiscussionDestination> destinations;
  final int notificationUnreadCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final bool expanded = AppBreakpoints.isExpanded(context);
    final EditorialColors colors = EditorialColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String nickname =
        AuthStore.instance.currentUser?.nickname.trim() ?? '';
    final String avatarLabel = nickname.isEmpty
        ? uiText(context, zh: '匿', en: 'A')
        : nickname.characters.first;

    return Container(
      key: const Key('desktop-primary-navigation'),
      width: expanded ? 248 : 84,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? AppSpacing.sm : AppSpacing.xs,
            ),
            child: expanded
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => onSelect(0),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.xxs),
                        child: AppSealMark(size: 36),
                      ),
                    ),
                  )
                : Center(
                    child: InkWell(
                      onTap: () => onSelect(0),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.xxs),
                        child: AppSealMark(size: 36),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (int index = 0; index < destinations.length; index++)
            _RailAction(
              icon: destinations[index].icon,
              label: destinations[index].label,
              selected: currentIndex == index,
              expanded: expanded,
              onTap: () => onSelect(index),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('create-post-top-action'),
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 46),
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AppSpacing.md : 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: expanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Text(l10n.publishVoice),
                    ],
                  )
                : const Icon(Icons.edit_outlined, size: 19),
          ),
          const Spacer(),
          _RailAction(
            icon: Icons.search_rounded,
            label: l10n.search,
            expanded: expanded,
            onTap: onSearch,
          ),
          _RailAction(
            icon: Icons.notifications_none_rounded,
            label: l10n.notifications,
            badge: notificationUnreadCount,
            expanded: expanded,
            onTap: onNotifications,
          ),
          _RailAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.conversations,
            expanded: expanded,
            onTap: onMessages,
          ),
          _RailAction(
            icon: Icons.settings_outlined,
            label: l10n.settings,
            expanded: expanded,
            onTap: onSettings,
          ),
          const SizedBox(height: AppSpacing.xs),
          Divider(color: colors.line),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onProfile,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      avatarLabel,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (expanded) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        nickname.isEmpty ? l10n.personalCenter : nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
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
    final EditorialColors colors = EditorialColors.of(context);
    final Color foreground = selected ? colors.ink : colors.mutedInk;
    final Widget iconWidget = Badge(
      isLabelVisible: badge > 0,
      label: Text(badge > 99 ? '99+' : '$badge'),
      child: Icon(icon, size: 21, color: foreground),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: expanded
                  ? Row(
                      children: <Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        iconWidget,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: foreground,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
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

class _DiscussionDestination {
  const _DiscussionDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
