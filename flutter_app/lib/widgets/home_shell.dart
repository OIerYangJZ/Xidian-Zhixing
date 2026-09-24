import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_store.dart';
import '../core/navigation/post_detail_nav.dart';
import '../core/network/api_exception.dart';
import '../core/navigation/share_links.dart';
import '../features/profile/public_user_profile_page.dart';
import '../core/navigation/url_query_state.dart';
import '../core/state/app_locale_store.dart';
import '../core/state/app_theme_store.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../core/widgets/app_surfaces.dart';
import '../core/widgets/language_toggle.dart';
import '../core/widgets/theme_dropdown.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';
import '../features/ai/ai_page.dart';
import '../features/campus/campus_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/post/create_post_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/search/search_page.dart';
import 'discussion_home_scaffold.dart';
import '../core/l10n/ui_text.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _postUrlHandled = false;
  final Map<int, Widget> _pageCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePostFromUrlIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<_ShellDestination> destinations = <_ShellDestination>[
      _ShellDestination(
        l10n.treehole,
        l10n.treeholeSubtitle,
        Icons.forum_outlined,
      ),
      _ShellDestination(
        l10n.campus,
        l10n.campusSubtitle,
        Icons.account_balance_outlined,
      ),
      _ShellDestination(
        l10n.campusAi,
        l10n.campusAiSubtitle,
        Icons.auto_awesome_outlined,
      ),
    ];
    final double width = MediaQuery.sizeOf(context).width;
    final bool desktop = width >= AppBreakpoints.medium;
    final bool expandedRail = width >= AppBreakpoints.expanded;
    final NotificationsState notificationsState = ref.watch(
      notificationsControllerProvider,
    );
    final int notificationUnreadCount = notificationsState.unreadCount;

    final Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.pageMaxWidth),
        child: _pageForIndex(_currentIndex),
      ),
    );

    if (AppColorThemes.usesDiscussionLayout(AppThemeStore.instance.themeKey)) {
      return DiscussionHomeScaffold(
        currentIndex: _currentIndex,
        content: content,
        notificationUnreadCount: notificationUnreadCount,
        onSelect: _selectTab,
        onCreate: _openCreatePost,
        onFilter: _openFeedFilters,
        onSearch: _openSearch,
        onNotifications: _openNotifications,
        onMessages: _openMessages,
        onSettings: _openSettings,
        onProfile: _openProfileSheet,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: desktop ? 30 : 16,
        title: Row(
          children: <Widget>[
            if (!desktop) ...<Widget>[
              const AppSealMark(size: 32),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    destinations[_currentIndex].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: desktop
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destinations[_currentIndex].subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (_currentIndex == 0 && !desktop)
            IconButton(
              tooltip: l10n.filter,
              onPressed: _openFeedFilters,
              icon: const Icon(Icons.menu_rounded),
            ),
          if (desktop)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ThemeDropdown(
                themeKey: AppThemeStore.instance.themeKey,
                locale: Localizations.localeOf(context),
                onChanged: AppThemeStore.instance.setThemeKey,
                compact: true,
              ),
            ),
          if (desktop)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: LanguageToggle(
                locale: Localizations.localeOf(context),
                onChanged: AppLocaleStore.instance.setLocale,
                compact: true,
              ),
            ),
          if (desktop)
            _DesktopSearchButton(onPressed: _openSearch, label: l10n.search)
          else if (_currentIndex == 0)
            IconButton(
              tooltip: l10n.search,
              onPressed: _openSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          IconButton(
            onPressed: _openNotifications,
            tooltip: l10n.notifications,
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
          if (!desktop)
            IconButton(
              onPressed: _openSettings,
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          if (desktop && _currentIndex == 0) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            FilledButton.icon(
              key: const Key('create-post-top-action'),
              onPressed: _openCreatePost,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.publishVoice),
            ),
          ],
          SizedBox(width: desktop ? AppSpacing.lg : AppSpacing.xs),
        ],
      ),
      body: desktop
          ? Row(
              children: <Widget>[
                _DesktopRail(
                  currentIndex: _currentIndex,
                  destinations: destinations,
                  onSelect: _selectTab,
                  extended: expandedRail,
                  onProfile: _openProfileSheet,
                ),
                Expanded(child: content),
              ],
            )
          : content,
      floatingActionButton: _currentIndex == 0
          ? (desktop
                ? null
                : FloatingActionButton(
                    key: const Key('create-post-fab'),
                    onPressed: _openCreatePost,
                    tooltip: l10n.createPost,
                    child: const Icon(Icons.edit_outlined),
                  ))
          : null,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              key: const Key('mobile-primary-navigation'),
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
              destinations: destinations
                  .map(
                    (_ShellDestination item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: _selectedIcon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _pageForIndex(int index) {
    return _pageCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return const FeedPage();
        case 1:
          return const CampusPage();
        case 2:
          return const AiPage();
        default:
          return const FeedPage();
      }
    });
  }

  Widget _selectedIcon(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18),
    );
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openCreatePost() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreatePostPage()),
    );
    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.published)),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterPage()),
    );
    if (!mounted) {
      return;
    }
    await ref.read(notificationsControllerProvider.notifier).refresh();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SearchPage(autofocus: true),
      ),
    );
  }

  void _openFeedFilters() {
    FeedPage.openFilterSheet(context, ref);
  }

  void _openMessages() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MessagesPage()));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openProfileSheet() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l10n.profileAndSettings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: PreferredSize(
                          preferredSize: const Size.fromHeight(56),
                          child: AppBar(title: Text(l10n.profileAndSettings)),
                        ),
                        body: const ProfilePage(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: Text(l10n.conversations),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MessagesPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.settings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restorePostFromUrlIfNeeded() async {
    if (_postUrlHandled) {
      return;
    }
    _postUrlHandled = true;
    final ShareLink? link = currentShareLink();
    if (link != null) {
      clearShareLinkFromUrl();
      switch (link.kind) {
        case ShareLinkKind.post:
          await _openLinkedPost(link.id);
        case ShareLinkKind.user:
          // The profile page loads the user itself and shows its error
          // panel when that fails.
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicUserProfilePage(userId: link.id),
            ),
          );
      }
      return;
    }
    final String? postId = currentPostIdFromUrl();
    if (postId == null || postId.trim().isEmpty) {
      return;
    }
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) {
        return;
      }
      await openPostDetailPage(context, post: post);
    } catch (_) {
      setPostIdOnUrl(null);
    }
  }

  /// Unlike a reload restore, a shared link was followed on purpose, so a
  /// post that is gone or hidden from this viewer is reported, not skipped.
  Future<void> _openLinkedPost(String postId) async {
    final PostItem post;
    try {
      post = await AppRepositories.posts.fetchPostDetail(postId);
    } on ApiException catch (error) {
      _showLinkError(
        error.statusCode == 404
            ? uiTextGlobal(
                zh: '帖子不存在，或你没有权限查看',
                en: 'This post does not exist or is not visible to you',
              )
            : uiTextGlobal(
                zh: '帖子打开失败：${error.message}',
                en: 'Could not open the post: ${error.message}',
              ),
      );
      return;
    } catch (error) {
      _showLinkError(
        uiTextGlobal(
          zh: '帖子打开失败：$error',
          en: 'Could not open the post: $error',
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    await openPostDetailPage(context, post: post);
  }

  void _showLinkError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    required this.extended,
    required this.onProfile,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelect;
  final bool extended;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors palette = EditorialColors.of(context);
    final user = AuthStore.instance.currentUser;
    final String nickname = user?.nickname.trim() ?? '';
    final String label = nickname.isEmpty
        ? uiText(context, zh: '匿', en: 'A')
        : nickname.characters.first;
    return Container(
      key: const Key('desktop-primary-navigation'),
      width: extended ? AppLayout.sidebarWidth : 76,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(extended ? 8 : 4, 0, 4, 24),
            child: extended
                ? Row(
                    children: <Widget>[
                      const AppSealMark(size: 38),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.brandShort,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              l10n.tagline,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const AppSealMark(size: 36),
          ),
          for (int index = 0; index < destinations.length; index++) ...<Widget>[
            _RailItem(
              destination: destinations[index],
              selected: currentIndex == index,
              onTap: () => onSelect(index),
              extended: extended,
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: onProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: extended
                  ? Row(
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.primarySubtle,
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: palette.primaryActive,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                nickname.isEmpty
                                    ? l10n.personalCenter
                                    : nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                l10n.profileAndSettings,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.extended,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Tooltip(
      message: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(
            horizontal: extended ? AppSpacing.sm : 0,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: extended
              ? Row(
                  children: <Widget>[
                    Icon(destination.icon, color: color, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            destination.label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            destination.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.68),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(destination.icon, color: color, size: 20),
                    const SizedBox(height: 3),
                    Text(
                      destination.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DesktopSearchButton extends StatelessWidget {
  const _DesktopSearchButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.search_rounded, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          backgroundColor: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;
}
