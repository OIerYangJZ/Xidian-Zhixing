import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/post_detail_nav.dart';
import '../core/network/api_exception.dart';
import '../core/navigation/share_links.dart';
import '../features/profile/public_user_profile_page.dart';
import '../core/navigation/url_query_state.dart';
import '../core/theme/design_tokens.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';
import '../features/ai/ai_page.dart';
import '../features/post/post_unavailable_page.dart';
import '../features/campus/campus_page.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_controller.dart';
import '../features/messages/messages_page.dart';
import '../models/conversation_item.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/post/create_post_page.dart';
import '../features/profile/settings_page.dart';
import '../features/search/search_page.dart';
import 'discussion_home_scaffold.dart';
import 'profile_menu.dart';
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
      // Conversations feed the 会话 badge, so load them with the shell rather
      // than on the first visit to messages.
      final MessagesState messages = ref.read(messagesControllerProvider);
      if (messages.loading && messages.conversations.isEmpty) {
        ref.read(messagesControllerProvider.notifier).loadInitial();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
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

    final int messageUnreadCount = ref
        .watch(messagesControllerProvider)
        .conversations
        .fold<int>(0, (int sum, ConversationItem c) => sum + c.unreadCount);
    return DiscussionHomeScaffold(
      currentIndex: _currentIndex,
      content: content,
      notificationUnreadCount: notificationUnreadCount,
      messageUnreadCount: messageUnreadCount,
      onSelect: _selectTab,
      onCreate: _openCreatePost,
      onFilter: _openFeedFilters,
      onSearch: _openSearch,
      onNotifications: _openNotifications,
      onMessages: _openMessages,
      onSettings: _openSettings,
      onProfile: () => showProfileMenu(
        context,
        wide: width >= DiscussionHomeScaffold.sidebarBreakpoint,
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
      // Gone, private and never-existed all answer 404: one page for all.
      if (error.statusCode == 404 || error.statusCode == 403) {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PostUnavailablePage(link: ShareLink.post(postId)),
            ),
          );
        }
        return;
      }
      _showLinkError(
        uiTextGlobal(
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
