import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_store.dart';
import '../core/navigation/post_detail_nav.dart';
import '../core/navigation/url_query_state.dart';
import '../core/theme/shared_colors.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';
import '../features/ai/ai_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/campus/campus_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/post/create_post_page.dart';
import '../features/profile/profile_page.dart';
import '../features/search/search_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _postUrlHandled = false;
  final Map<int, Widget> _pageCache = <int, Widget>{};

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination('树洞', '校园里的声音', Icons.forum_outlined),
    _ShellDestination('校园', '服务、日程、地图', Icons.account_balance_outlined),
    _ShellDestination('AI', '学习与校园问答', Icons.auto_awesome_outlined),
    _ShellDestination('公告', '重要消息', Icons.campaign_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePostFromUrlIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    final NotificationsState notificationsState = ref.watch(
      notificationsControllerProvider,
    );
    final int notificationUnreadCount = notificationsState.unreadCount;

    final Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1180 : double.infinity),
        child: _pageForIndex(_currentIndex),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: <Widget>[
            _avatarButton(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _destinations[_currentIndex].label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _destinations[_currentIndex].subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.58),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (_currentIndex == 0)
            IconButton(
              tooltip: '筛选',
              onPressed: _openFeedFilters,
              icon: const Icon(Icons.tune_rounded),
            ),
          if (_currentIndex == 0)
            IconButton(
              tooltip: '搜索',
              onPressed: _openSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          IconButton(
            onPressed: _openNotifications,
            tooltip: '通知',
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
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: <Widget>[
                _DesktopRail(
                  currentIndex: _currentIndex,
                  destinations: _destinations,
                  onSelect: _selectTab,
                ),
                Expanded(child: content),
              ],
            )
          : content,
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openCreatePost,
              tooltip: '发帖',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 70,
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
              destinations: _destinations
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
        case 3:
          return const AnnouncementsPage();
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

  Widget _avatarButton() {
    final user = AuthStore.instance.currentUser;
    final String avatarUrl = user?.avatarUrl.trim() ?? '';
    final String nickname = user?.nickname.trim() ?? '';
    final String label = nickname.isEmpty ? '匿' : nickname.characters.first;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openProfileSheet,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: SharedColors.softRed,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isEmpty
            ? Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SharedColors.deep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(label)),
              ),
      ),
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('帖子已发布')));
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
      MaterialPageRoute<void>(builder: (_) => const SearchPage(autofocus: true)),
    );
  }

  void _openFeedFilters() {
    FeedPage.openFilterSheet(context, ref);
  }

  void _openProfileSheet() {
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
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('个人中心'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: PreferredSize(
                          preferredSize: const Size.fromHeight(56),
                          child: AppBar(title: const Text('个人中心')),
                        ),
                        body: const ProfilePage(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('会话'),
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
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
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
          for (int index = 0; index < destinations.length; index++) ...<Widget>[
            _RailItem(
              destination: destinations[index],
              selected: currentIndex == index,
              onTap: () => onSelect(index),
            ),
            const SizedBox(height: 8),
          ],
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
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Tooltip(
      message: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(destination.icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                destination.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
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
