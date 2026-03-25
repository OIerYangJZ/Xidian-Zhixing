import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';

/// 移动端主 Shell
/// 包含底部 Tab 导航栏（Twitter 风格：纯白背景 + 顶部 0.5px 细线，无阴影）
class MobileShell extends ConsumerWidget {
  const MobileShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageUnreadCount = ref.watch(messageUnreadCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE8E8E8),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          onTap: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedItemColor: MobileTheme.primary,
          unselectedItemColor: MobileTheme.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 0
                    ? Icons.home
                    : Icons.home_outlined,
              ),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 1
                    ? Icons.search
                    : Icons.search_outlined,
              ),
              label: '搜索',
            ),
            BottomNavigationBarItem(
              icon: _buildMessageIcon(false, messageUnreadCount),
              activeIcon: _buildMessageIcon(true, messageUnreadCount),
              label: '消息',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 3
                    ? Icons.star
                    : Icons.star_outline,
              ),
              label: '收藏',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                navigationShell.currentIndex == 4
                    ? Icons.person
                    : Icons.person_outline,
              ),
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
        smallSize: 8,
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
