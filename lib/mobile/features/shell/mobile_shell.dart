import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';

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

  /// 未登录时底部栏只有 3 项（首页/消息/我的），对应 branch 0、1、3；「校园」仅对已登录用户展示。
  static int _displayIndexForBranch(bool loggedIn, int branchIndex) {
    if (loggedIn) return branchIndex;
    if (branchIndex <= 1) return branchIndex;
    if (branchIndex == 3) return 2;
    return 0;
  }

  static int _branchIndexForDisplay(bool loggedIn, int displayIndex) {
    if (loggedIn) return displayIndex;
    return [0, 1, 3][displayIndex];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageUnreadCount = ref.watch(messageUnreadCountProvider);

    return ListenableBuilder(
      listenable: AuthStore.instance,
      builder: (context, _) {
        final loggedIn = AuthStore.instance.isAuthenticated;
        final branch = navigationShell.currentIndex;

        if (!loggedIn && branch == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) navigationShell.goBranch(0);
          });
        }

        final displayIndex = _displayIndexForBranch(loggedIn, branch);

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
              currentIndex: displayIndex,
              elevation: 0,
              backgroundColor: Colors.transparent,
              onTap: (index) {
                final target = _branchIndexForDisplay(loggedIn, index);
                navigationShell.goBranch(
                  target,
                  initialLocation: target == navigationShell.currentIndex,
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
                    branch == 0 ? Icons.home : Icons.home_outlined,
                  ),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: _buildMessageIcon(branch == 1, messageUnreadCount),
                  label: '消息',
                ),
                if (loggedIn)
                  BottomNavigationBarItem(
                    icon: Icon(
                      branch == 2 ? Icons.school : Icons.school_outlined,
                    ),
                    label: '校园',
                  ),
                BottomNavigationBarItem(
                  icon: Icon(
                    branch == 3 ? Icons.person : Icons.person_outline,
                  ),
                  label: '我的',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageIcon(bool selected, int unreadCount) {
    final icon = Icon(
      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
    );
    if (unreadCount > 0) {
      return Badge(
        smallSize: 8,
        label: Text(
          unreadCount > 99 ? '99+' : unreadCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: icon,
      );
    }
    return icon;
  }
}
