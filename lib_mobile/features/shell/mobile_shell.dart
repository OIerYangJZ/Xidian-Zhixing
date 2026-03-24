import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import '../home/home_page.dart';
import '../search/search_page.dart';
import '../messages/messages_page.dart';
import '../favorites/favorites_page.dart';
import '../profile/profile_page.dart';

/// 移动端主 Shell
/// 包含底部 Tab 导航栏
class MobileShell extends ConsumerWidget {
  const MobileShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationUnreadCount = ref.watch(notificationUnreadCountProvider);
    final messageUnreadCount = ref.watch(messageUnreadCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: MobileTheme.divider.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: '搜索',
            ),
            BottomNavigationBarItem(
              icon: _buildMessageIcon(false, messageUnreadCount),
              activeIcon: _buildMessageIcon(true, messageUnreadCount),
              label: '消息',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.star_outline),
              activeIcon: Icon(Icons.star),
              label: '收藏',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageIcon(bool active, int unreadCount) {
    if (unreadCount > 0) {
      return Badge(
        label: Text(
          unreadCount > 99 ? '99+' : unreadCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline),
      );
    }
    return Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline);
  }
}
