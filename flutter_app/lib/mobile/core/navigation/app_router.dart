import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/auth/admin_auth_store.dart';
import 'login_return.dart';
import '../../features/shell/mobile_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/search/search_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/post/post_detail_page.dart';
import '../../features/post/create_post_page.dart';
import '../../features/messages/chat_page.dart';
import '../../features/notifications/notification_center_page.dart';
import '../../features/profile/settings_main_page.dart';
import '../../features/profile/privacy_settings_page.dart';
import '../../features/profile/account_security_page.dart';
import '../../features/profile/display_settings_page.dart';
import '../../features/profile/about_page.dart';
import '../../features/profile/help_and_feedback_page.dart';
import '../../features/profile/acknowledgements_page.dart';
// Pages shared with the web, already on the design system; their links to
// posts, chats and profiles go through AppNavigation (mobile_app_entry).
import 'package:xdu_treehole_web/core/theme/app_theme.dart';
import 'package:xdu_treehole_web/features/admin/admin_console_page.dart' as web;
import 'package:xdu_treehole_web/features/auth/banned_account_page.dart' as web;
import 'package:xdu_treehole_web/features/admin/admin_login_page.dart' as web;
import 'package:xdu_treehole_web/features/me/my_comments_page.dart' as web;
import 'package:xdu_treehole_web/features/me/my_favorites_page.dart' as web;
import 'package:xdu_treehole_web/features/me/my_posts_page.dart' as web;
import 'package:xdu_treehole_web/features/me/my_reports_page.dart' as web;
import 'package:xdu_treehole_web/features/me/feedback_mailbox_page.dart' as web;
import 'package:xdu_treehole_web/features/profile/blocked_accounts_page.dart'
    as web;
import 'package:xdu_treehole_web/features/profile/edit_profile_page.dart'
    as web;
import 'package:xdu_treehole_web/features/profile/follow_list_page.dart' as web;
import 'package:xdu_treehole_web/features/profile/notification_preferences_page.dart'
    as web;
import 'package:xdu_treehole_web/features/profile/public_user_profile_page.dart'
    as web;
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/repositories/app_repositories.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/features/legal/terms_of_service_page.dart';
import 'package:xdu_treehole_web/features/legal/privacy_policy_page.dart';
import 'package:xdu_treehole_web/features/legal/community_guidelines_page.dart';
import 'package:xdu_treehole_web/features/legal/report_guidelines_page.dart';

/// 路由守卫：检查是否已登录
String? _authGuard(BuildContext context, GoRouterState state) {
  final isLoggedIn = AuthStore.instance.isAuthenticated;
  final isAdminLoggedIn = AdminAuthStore.instance.isAuthenticated;
  final isAuthRoute = state.matchedLocation.startsWith('/auth');
  final isAdminRoute = state.matchedLocation.startsWith('/admin');
  final isAdminLoginRoute = state.matchedLocation == '/admin/login';
  final isPublicRoute =
      state.matchedLocation == '/profile/help-feedback' ||
      state.matchedLocation.startsWith('/legal/');

  // 如果是管理员路由
  if (isAdminRoute) {
    if (!isAdminLoggedIn && !isAdminLoginRoute) {
      return '/admin/login';
    }
    if (isAdminLoggedIn && isAdminLoginRoute) {
      return '/admin';
    }
    return null;
  }

  // A banned session reaches only the appeal endpoints, so every other page
  // would be a screen of refused requests.
  final bool isBannedRoute = state.matchedLocation == '/banned';
  if (isLoggedIn && AuthStore.instance.isBanned) {
    return isBannedRoute || isPublicRoute ? null : '/banned';
  }
  if (isBannedRoute) {
    return isLoggedIn ? '/' : '/auth/login';
  }

  // 如果是认证路由
  if (isAuthRoute) {
    if (isLoggedIn) {
      return loginReturnLocation(state.uri);
    }
    return null;
  }

  // 其他路由需要登录（公开路由除外）。记下原本要去的地址，
  // 这样从帖子链接进来的用户登录后会回到那个帖子。
  if (!isLoggedIn && !isPublicRoute) {
    final String target = state.uri.toString();
    return target == '/'
        ? '/auth/login'
        : Uri(
            path: '/auth/login',
            queryParameters: <String, String>{'from': target},
          ).toString();
  }

  return null;
}

/// 路由配置
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthStore.instance,
  redirect: _authGuard,
  routes: [
    // 认证路由（未登录状态）
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginPage(),
    ),
    // The web's ban screen: appeal, its status, and signing out.
    GoRoute(
      path: '/banned',
      builder: (context, state) => const web.BannedAccountPage(),
    ),
    // 主页面（底部 Tab 导航）— 3 tabs: 首页 / 消息 / 我的
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MobileShell(navigationShell: navigationShell);
      },
      branches: [
        // 首页
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ],
        ),
        // 消息
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesPage(),
            ),
          ],
        ),
        // 我的
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),

    // 搜索（全屏，不在 Tab 内）
    GoRoute(
      path: '/search',
      builder: (context, state) =>
          SearchPage(initialKeyword: state.uri.queryParameters['q'] ?? ''),
    ),
    // 收藏（全屏，不在 Tab 内）
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const web.MyFavoritesPage(),
    ),

    // 他人主页
    GoRoute(
      path: '/user/:id',
      builder: (context, state) {
        final userId = state.pathParameters['id']!;
        return web.PublicUserProfilePage(userId: userId);
      },
    ),

    // 全屏页面（不在 Tab 内）
    GoRoute(
      path: '/post/create',
      builder: (context, state) => const CreatePostPage(),
    ),
    // Shared short links https://<site>/p/<id> and /u/<id>, delivered by
    // App Links.
    GoRoute(
      path: '/p/:id',
      redirect: (context, state) =>
          '/post/${Uri.encodeComponent(state.pathParameters['id']!)}',
    ),
    GoRoute(
      path: '/u/:id',
      redirect: (context, state) =>
          '/user/${Uri.encodeComponent(state.pathParameters['id']!)}',
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        final String? initialCommentId = state.uri.queryParameters['commentId'];
        return PostDetailPage(
          postId: postId,
          initialCommentId: initialCommentId,
        );
      },
    ),
    GoRoute(
      path: '/chat/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        final extra = state.uri.queryParameters;
        return ChatPage(
          conversationId: conversationId,
          peerName: extra['name'],
          peerAvatar: extra['avatar'],
          peerUserId: extra['userId'],
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
    GoRoute(
      path: '/users/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return web.PublicUserProfilePage(userId: userId);
      },
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const _EditProfileRoute(),
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const SettingsMainPage(),
    ),
    GoRoute(
      path: '/profile/settings/privacy',
      builder: (context, state) => const PrivacySettingsPage(),
    ),
    GoRoute(
      path: '/profile/settings/account',
      builder: (context, state) => const AccountSecurityPage(),
    ),
    GoRoute(
      path: '/profile/settings/display',
      builder: (context, state) => const DisplaySettingsPage(),
    ),
    GoRoute(
      path: '/profile/settings/about',
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '/profile/settings/notifications',
      builder: (context, state) => const web.NotificationPreferencesPage(),
    ),
    GoRoute(
      path: '/profile/follows',
      builder: (context, state) => web.FollowListPage(
        initialTab: switch (state.uri.queryParameters['tab']) {
          'followers' => web.FollowListTab.followers,
          'friends' => web.FollowListTab.friends,
          _ => web.FollowListTab.following,
        },
      ),
    ),
    GoRoute(
      path: '/profile/settings/blocked',
      builder: (context, state) => const web.BlockedAccountsPage(),
    ),
    GoRoute(
      path: '/profile/posts',
      builder: (context, state) => const web.MyPostsPage(),
    ),
    GoRoute(
      path: '/profile/comments',
      builder: (context, state) => const web.MyCommentsPage(),
    ),
    GoRoute(
      path: '/profile/reports',
      builder: (context, state) => const web.MyReportsPage(),
    ),
    GoRoute(
      path: '/profile/feedback',
      builder: (context, state) => const web.FeedbackMailboxPage(),
    ),
    GoRoute(
      path: '/profile/help-feedback',
      builder: (context, state) => const HelpAndFeedbackPage(),
    ),
    GoRoute(
      path: '/profile/acknowledgements',
      builder: (context, state) => const AcknowledgementsPage(),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (context, state) => const TermsOfServicePage(),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: '/legal/guidelines',
      builder: (context, state) => const CommunityGuidelinesPage(),
    ),
    GoRoute(
      path: '/legal/report',
      builder: (context, state) => const ReportGuidelinesPage(),
    ),

    // 管理员路由: the web admin console, which also lays out for phones.
    GoRoute(
      path: '/admin/login',
      builder: (context, state) =>
          web.AdminLoginPage(onSignedIn: () => context.go('/admin')),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => Theme(
        // 书院·青绿 marks the admin side apart from the student app.
        data: AppTheme.designSystemFor(
          themeKey: 'zhuqing',
          brightness: Theme.of(context).brightness,
        ),
        child: web.AdminConsolePage(
          repository: AppRepositories.adminPortal,
          onLogout: () async {
            await AppRepositories.adminAuth.logout();
            if (context.mounted) context.go('/admin/login');
          },
        ),
      ),
    ),
  ],
);

/// The shared 编辑资料 takes the profile it edits: the signed-in user when
/// already known, otherwise fetched first.
class _EditProfileRoute extends StatelessWidget {
  const _EditProfileRoute();

  @override
  Widget build(BuildContext context) {
    final UserProfile? cached = AuthStore.instance.currentUser;
    if (cached != null) return web.EditProfilePage(profile: cached);
    return FutureBuilder<UserProfile>(
      future: AppRepositories.users.fetchProfile(),
      builder: (BuildContext context, AsyncSnapshot<UserProfile> snap) {
        if (snap.hasData) return web.EditProfilePage(profile: snap.data!);
        return Scaffold(
          appBar: AppBar(title: const Text('编辑资料')),
          body: snap.hasError
              ? ZxStatePanel(
                  error: true,
                  icon: Icons.error_outline_rounded,
                  title: '资料加载失败',
                  message: '${snap.error}',
                )
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
