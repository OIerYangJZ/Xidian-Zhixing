import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_store.dart';
import '../core/navigation/post_detail_nav.dart';
import '../core/navigation/url_query_state.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../core/widgets/app_surfaces.dart';
import '../features/ai/ai_page.dart';
import '../features/campus/campus_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/post/create_post_page.dart';
import '../features/profile/public_user_profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/search/search_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _postUrlHandled = false;
  bool _settingsOpen = false;
  final Map<int, Widget> _pageCache = <int, Widget>{};
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restorePostFromUrlIfNeeded(),
    );
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
    final bool desktop = AppBreakpoints.isDesktop(context);
    final bool expandedRail = AppBreakpoints.isExpanded(context);
    final int unread = ref.watch(notificationsControllerProvider).unreadCount;
    final Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.pageMaxWidth),
        child: _pageForIndex(_currentIndex),
      ),
    );

    return Scaffold(
      backgroundColor: EditorialColors.of(context).page,
      appBar: desktop
          ? null
          : AppBar(
              titleSpacing: AppSpacing.md,
              title: _MobileTitle(destination: destinations[_currentIndex]),
              actions: <Widget>[
                IconButton(
                  onPressed: _openSearch,
                  tooltip: l10n.search,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  onPressed: _openNotifications,
                  tooltip: l10n.notifications,
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
      body: desktop
          ? Row(
              children: <Widget>[
                if (!_settingsOpen)
                  _DesktopRail(
                    currentIndex: _currentIndex,
                    destinations: destinations,
                    extended: expandedRail,
                    unread: unread,
                    onSelect: _selectTab,
                    onCreate: _openCreatePost,
                    onSearch: _openSearch,
                    onNotifications: _openNotifications,
                    onMessages: _openMessages,
                    onSettings: _openSettings,
                    onProfile: _openProfile,
                  ),
                Expanded(
                  child: Navigator(
                    key: _contentNavigatorKey,
                    onGenerateRoute: (RouteSettings settings) =>
                        MaterialPageRoute<void>(
                          settings: settings,
                          builder: (_) => content,
                        ),
                  ),
                ),
              ],
            )
          : content,
      floatingActionButton: desktop || _currentIndex != 0
          ? null
          : FloatingActionButton(
              key: const Key('create-post-fab'),
              onPressed: _openCreatePost,
              tooltip: l10n.createPost,
              child: const Icon(Icons.edit_outlined),
            ),
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
                      selectedIcon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _pageForIndex(int index) => _pageCache.putIfAbsent(index, () {
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

  void _selectTab(int index) {
    if (AppBreakpoints.isDesktop(context)) {
      if (index != _currentIndex) setState(() => _currentIndex = index);
      _contentNavigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => _newPageForIndex(index)),
        (Route<dynamic> route) => false,
      );
      return;
    }
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  Widget _newPageForIndex(int index) {
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
  }

  NavigatorState get _contentNavigator => AppBreakpoints.isDesktop(context)
      ? _contentNavigatorKey.currentState!
      : Navigator.of(context);

  Future<void> _openCreatePost() async {
    final bool? created = await showCreatePostComposer(
      _contentNavigator.context,
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.published)),
    );
  }

  Future<void> _openNotifications() async {
    await _contentNavigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterPage()),
    );
    if (!mounted) return;
    await ref.read(notificationsControllerProvider.notifier).refresh();
  }

  void _openSearch() => _contentNavigator.push(
    MaterialPageRoute<void>(builder: (_) => const SearchPage(autofocus: true)),
  );

  Future<void> _openProfile() async {
    try {
      final profile = await AppRepositories.users.fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      await _contentNavigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PublicUserProfilePage(userId: profile.userId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开个人主页：$error')));
    }
  }

  void _openMessages() => _contentNavigator.push(
    MaterialPageRoute<void>(builder: (_) => const MessagesPage()),
  );

  Future<void> _openSettings() async {
    setState(() => _settingsOpen = true);
    await _contentNavigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
    if (mounted) setState(() => _settingsOpen = false);
  }

  Future<void> _restorePostFromUrlIfNeeded() async {
    if (_postUrlHandled) return;
    _postUrlHandled = true;
    final String? postId = currentPostIdFromUrl();
    if (postId == null || postId.trim().isEmpty) return;
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) return;
      final BuildContext routeContext = AppBreakpoints.isDesktop(context)
          ? _contentNavigatorKey.currentContext!
          : context;
      await openPostDetailPage(routeContext, post: post);
    } catch (_) {
      setPostIdOnUrl(null);
    }
  }
}

class _MobileTitle extends StatelessWidget {
  const _MobileTitle({required this.destination});
  final _ShellDestination destination;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(destination.label, style: Theme.of(context).textTheme.titleMedium),
      Text(destination.subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.currentIndex,
    required this.destinations,
    required this.extended,
    required this.unread,
    required this.onSelect,
    required this.onCreate,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onSettings,
    required this.onProfile,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final bool extended;
  final int unread;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors colors = EditorialColors.of(context);
    final String nickname =
        AuthStore.instance.currentUser?.nickname.trim() ?? '';
    final String avatarLabel = nickname.isEmpty
        ? '匿'
        : nickname.characters.first;
    return Container(
      key: const Key('desktop-primary-navigation'),
      width: extended ? AppLayout.sidebarWidth : AppLayout.compactSidebarWidth,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      color: colors.darkPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RailBrand(extended: extended, onTap: () => onSelect(0)),
          const SizedBox(height: AppSpacing.xl),
          for (int index = 0; index < destinations.length; index++) ...<Widget>[
            _RailItem(
              destination: destinations[index],
              selected: currentIndex == index,
              extended: extended,
              onTap: () => onSelect(index),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.sm),
          Tooltip(
            message: l10n.publishVoice,
            child: FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onDarkPanel,
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? AppSpacing.md : 0,
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: extended
                  ? Text(l10n.publishVoice)
                  : const SizedBox.shrink(),
            ),
          ),
          const Spacer(),
          _RailUtility(
            icon: Icons.search_rounded,
            label: l10n.search,
            extended: extended,
            onTap: onSearch,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _RailUtility(
            icon: Icons.notifications_none_rounded,
            label: l10n.notifications,
            extended: extended,
            badge: unread,
            onTap: onNotifications,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _RailUtility(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.conversations,
            extended: extended,
            onTap: onMessages,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _RailUtility(
            icon: Icons.settings_outlined,
            label: l10n.settings,
            extended: extended,
            onTap: onSettings,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.railMuted.withValues(alpha: 0.22)),
          const SizedBox(height: AppSpacing.md),
          _RailProfile(
            label: avatarLabel,
            nickname: nickname,
            extended: extended,
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended, required this.onTap});
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.xs : 0),
        child: extended
            ? const Align(
                alignment: Alignment.centerLeft,
                child: AppBrandLogo(size: 32),
              )
            : const Center(child: AppBrandLogo(size: 32)),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });
  final _ShellDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color foreground = selected ? colors.onDarkPanel : colors.railMuted;
    return Tooltip(
      message: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.standard),
          curve: AppMotion.emphasis,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: extended ? AppSpacing.sm : 0,
          ),
          decoration: const BoxDecoration(),
          child: extended
              ? Row(
                  children: <Widget>[
                    Icon(destination.icon, size: 20, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        destination.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(destination.icon, size: 20, color: foreground),
                ),
        ),
      ),
    );
  }
}

class _RailUtility extends StatelessWidget {
  const _RailUtility({
    required this.icon,
    required this.label,
    required this.extended,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final bool extended;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AppSpacing.sm : 0,
            ),
            child: extended
                ? Row(
                    children: <Widget>[
                      Badge(
                        isLabelVisible: badge > 0,
                        label: Text(badge > 99 ? '99+' : '$badge'),
                        child: Icon(icon, color: colors.railMuted, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.railMuted),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Badge(
                      isLabelVisible: badge > 0,
                      label: Text('$badge'),
                      child: Icon(icon, color: colors.railMuted, size: 20),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RailProfile extends StatelessWidget {
  const _RailProfile({
    required this.label,
    required this.nickname,
    required this.extended,
    required this.onTap,
  });
  final String label;
  final String nickname;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Padding(
        padding: EdgeInsets.all(extended ? AppSpacing.xs : 0),
        child: extended
            ? Row(
                children: <Widget>[
                  _RailAvatar(label: label),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      nickname.isEmpty ? '个人中心' : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onDarkPanel,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.more_horiz_rounded,
                    color: colors.railMuted,
                    size: 18,
                  ),
                ],
              )
            : Center(child: _RailAvatar(label: label)),
      ),
    );
  }
}

class _RailAvatar extends StatelessWidget {
  const _RailAvatar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.railSelected,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.onDarkPanel),
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
