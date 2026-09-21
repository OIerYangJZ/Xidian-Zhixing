import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_store.dart';
import '../features/auth/login_page.dart';
import '../core/navigation/post_detail_nav.dart';
import '../core/navigation/url_query_state.dart';
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

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _postUrlHandled = false;
  final Map<int, Widget> _pageCache = <int, Widget>{};
  final List<GlobalKey<NavigatorState>> _sectionNavigators =
      List<GlobalKey<NavigatorState>>.generate(
        8,
        (_) => GlobalKey<NavigatorState>(),
      );

  BuildContext get _sectionContext =>
      _sectionNavigators[_currentIndex].currentState!.overlay!.context;

  @override
  void initState() {
    super.initState();
    AuthStore.instance.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePostFromUrlIfNeeded();
    });
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_authChanged);
    super.dispose();
  }

  void _authChanged() {
    if (AuthStore.instance.isAuthenticated) return;
    // Signing out inside a section must leave the entire authenticated shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotificationsState notificationsState = ref.watch(
      notificationsControllerProvider,
    );
    _pageForIndex(_currentIndex);
    final Widget content = IndexedStack(
      index: _currentIndex,
      sizing: StackFit.expand,
      children: List<Widget>.generate(
        8,
        (index) => TickerMode(
          enabled: index == _currentIndex,
          child: NavigatorPopHandler<Object?>(
            enabled: index == _currentIndex,
            onPopWithResult: (result) =>
                _sectionNavigators[index].currentState!.pop(result),
            child: _pageCache[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

    return DiscussionHomeScaffold(
      currentIndex: _currentIndex,
      content: content,
      notificationUnreadCount: notificationsState.unreadCount,
      onSelect: _selectTab,
      onCreate: _openCreatePost,
      onFilter: _openFeedFilters,
      onSearch: _openSearch,
      onNotifications: _openNotifications,
      onMessages: _openMessages,
      onSettings: _openSettings,
      onProfile: _openProfile,
    );
  }

  // Shared section indices: home 0, Campus 1, AI 2, search 3,
  // notifications 4, chat 5, profile 6, settings 7.
  // Feature Navigator.push calls remain inside their section's navigator.
  Widget _pageForIndex(int index) {
    return _pageCache.putIfAbsent(
      index,
      () => Navigator(
        key: _sectionNavigators[index],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => switch (index) {
            0 => const FeedPage(),
            1 => const CampusPage(),
            2 => const AiPage(),
            3 => const SearchPage(autofocus: true),
            4 => const NotificationCenterPage(),
            5 => const MessagesPage(),
            6 => const Scaffold(body: ProfilePage()),
            7 => const SettingsPage(),
            _ => throw ArgumentError.value(index, 'index'),
          },
        ),
      ),
    );
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (index == _currentIndex) {
      _sectionNavigators[index].currentState!.popUntil(
        (route) => route.isFirst,
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _openCreatePost() async {
    final bool? created = await _sectionNavigators[_currentIndex].currentState!
        .push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const CreatePostPage()),
        );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.published)),
    );
  }

  void _openNotifications() {
    _selectTab(4);
    ref.read(notificationsControllerProvider.notifier).refresh();
  }

  void _openSearch() => _selectTab(3);

  void _openFeedFilters() => FeedPage.openFilterSheet(_sectionContext, ref);

  void _openMessages() => _selectTab(5);

  void _openSettings() => _selectTab(7);

  void _openProfile() => _selectTab(6);

  Future<void> _restorePostFromUrlIfNeeded() async {
    if (_postUrlHandled) return;
    _postUrlHandled = true;
    final String? postId = currentPostIdFromUrl();
    if (postId == null || postId.trim().isEmpty) return;
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) return;
      await openPostDetailPage(_sectionContext, post: post);
    } catch (_) {
      setPostIdOnUrl(null);
    }
  }
}
