import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/auth/admin_auth_store.dart';
import '../../features/shell/mobile_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/verify_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/home/home_page.dart';
import '../../features/search/search_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/post/post_detail_page.dart';
import '../../features/post/create_post_page.dart';
import '../../features/messages/chat_page.dart';
import '../../features/notifications/notification_center_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/settings_page.dart';
import '../../features/profile/my_posts_page.dart';
import '../../features/profile/my_comments_page.dart';
import '../../features/profile/my_reports_page.dart';
import '../../features/admin/admin_login_page.dart';
import '../../features/admin/admin_console_page.dart';

/// 路由守卫：检查是否已登录
String? _authGuard(BuildContext context, GoRouterState state) {
  final isLoggedIn = AuthStore.instance.isAuthenticated;
  final isAdminLoggedIn = AdminAuthStore.instance.isAuthenticated;
  final isAuthRoute = state.matchedLocation.startsWith('/auth');
  final isAdminRoute = state.matchedLocation.startsWith('/admin');
  final isAdminLoginRoute = state.matchedLocation == '/admin/login';

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

  // 如果是认证路由
  if (isAuthRoute) {
    if (isLoggedIn) {
      return '/';
    }
    return null;
  }

  // 其他路由需要登录
  if (!isLoggedIn) {
    return '/auth/login';
  }

  return null;
}

/// 路由配置
final appRouter = GoRouter(
  initialLocation: '/',
  redirect: _authGuard,
  routes: [
    // 认证路由（未登录状态）
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/auth/verify',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        return VerifyPage(email: email);
      },
    ),
    GoRoute(
      path: '/auth/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),

    // 主页面（底部 Tab 导航）
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MobileShell(navigationShell: navigationShell);
      },
      branches: [
        // 首页
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // 搜索
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchPage(),
            ),
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
        // 收藏
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesPage(),
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

    // 全屏页面（不在 Tab 内）
    GoRoute(
      path: '/post/create',
      builder: (context, state) => const CreatePostPage(),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        return PostDetailPage(postId: postId);
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
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/profile/posts',
      builder: (context, state) => const MyPostsPage(),
    ),
    GoRoute(
      path: '/profile/comments',
      builder: (context, state) => const MyCommentsPage(),
    ),
    GoRoute(
      path: '/profile/reports',
      builder: (context, state) => const MyReportsPage(),
    ),

    // 管理员路由
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminConsolePage(),
    ),
  ],
);
