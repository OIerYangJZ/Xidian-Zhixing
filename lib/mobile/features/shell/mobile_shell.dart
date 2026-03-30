import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import '../home/home_page.dart';
import '../messages/messages_page.dart';
import '../xdyou/xdyou_host_page.dart';
import '../profile/profile_page.dart';

/// 底部导航栏显示/隐藏状态全局 ChangeNotifier
/// 首页向上滚动时隐藏，向下滚动时显示
class BottomNavVisibilityNotifier extends ChangeNotifier {
  bool _visible = true;
  bool get visible => _visible;

  void show() {
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  static final BottomNavVisibilityNotifier instance =
      BottomNavVisibilityNotifier._();
  BottomNavVisibilityNotifier._();
}

/// 移动端主 Shell
/// 包含底部 Tab 导航栏（Twitter 风格：纯白背景 + 顶部 0.5px 细线，无阴影）
/// 支持：左右滑动切换 Tab、首页滑动时自动收起底部栏、通知红点 Badge
class MobileShell extends ConsumerStatefulWidget {
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
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell>
    with TickerProviderStateMixin {
  /// 记录是否已提示"再按一次退出"
  bool _backHintShown = false;

  /// PageView 控制器（用于左右滑动切换 Tab）
  late final PageController _pageController;

  /// 底部栏动画
  late final AnimationController _navAnimController;
  late final Animation<double> _navSlideAnim;
  bool _navAnimating = false;

  /// 当前活跃 display index（用于同步 PageView）
  int _currentDisplayIndex = 0;

  /// 当前是否由 PageView 驱动的切换（避免循环触发）
  bool _isPageViewScrolling = false;

  @override
  void initState() {
    super.initState();

    _currentDisplayIndex = widget.navigationShell.currentIndex;
    _pageController = PageController(initialPage: _currentDisplayIndex);

    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _navSlideAnim = Tween<double>(begin: 0, end: 80).animate(
      CurvedAnimation(parent: _navAnimController, curve: Curves.easeInOut),
    );

    BottomNavVisibilityNotifier.instance.addListener(_onNavVisibilityChanged);
  }

  void _onNavVisibilityChanged() {
    if (!mounted) return;
    final shouldHide = !BottomNavVisibilityNotifier.instance.visible;
    if (shouldHide && !_navAnimating) {
      _navAnimating = true;
      _navAnimController.forward().then((_) {
        if (mounted) _navAnimating = false;
      });
    } else if (!shouldHide && _navAnimating) {
      _navAnimating = true;
      _navAnimController.reverse().then((_) {
        if (mounted) _navAnimating = false;
      });
    } else if (!shouldHide) {
      _navAnimController.reverse();
    } else {
      _navAnimController.forward();
    }
  }

  @override
  void dispose() {
    BottomNavVisibilityNotifier.instance.removeListener(_onNavVisibilityChanged);
    _pageController.dispose();
    _navAnimController.dispose();
    super.dispose();
  }

  /// 切换到指定 Tab（由底部栏点击或 PageView 滑动触发）
  void _switchToTab(int displayIndex, {bool fromPageView = false}) {
    if (displayIndex == _currentDisplayIndex) return;

    if (fromPageView) {
      _isPageViewScrolling = true;
      _currentDisplayIndex = displayIndex;
    } else {
      _currentDisplayIndex = displayIndex;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(displayIndex);
      }
    }

    final loggedIn = AuthStore.instance.isAuthenticated;
    final target = MobileShell._branchIndexForDisplay(loggedIn, displayIndex);

    // 延迟到当前帧结束后执行，避免 PageView 动画未完成时 goBranch 被 GoRouter 拒绝
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.navigationShell.goBranch(
        target,
        initialLocation: target == widget.navigationShell.currentIndex,
      );
    });
  }

  /// PageView 滑动结束回调
  void _onPageViewChanged(int index) {
    _currentDisplayIndex = index;
    _isPageViewScrolling = false;
    _switchToTab(index, fromPageView: true);
  }

  /// 处理硬件/系统返回键
  Future<void> _handleBackPress(int branch) async {
    if (!mounted) return;

    if (branch == 0) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      if (_backHintShown) {
        exit(0);
      } else {
        _backHintShown = true;
        _scrollHomeToTop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次退出应用'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) _backHintShown = false;
        });
      }
    } else {
      if (_backHintShown) {
        exit(0);
      } else {
        _backHintShown = true;
        widget.navigationShell.goBranch(0);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次退出应用'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) _backHintShown = false;
        });
      }
    }
  }

  void _scrollHomeToTop() {
    ref.read(scrollToTopTriggerProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final messageUnreadCount = ref.watch(messageUnreadCountProvider);
    final notificationsState = ref.watch(notificationsControllerProvider);
    final notificationUnreadCount = notificationsState.unreadCount;

    return ListenableBuilder(
      listenable: AuthStore.instance,
      builder: (context, _) {
        final loggedIn = AuthStore.instance.isAuthenticated;
        final branch = widget.navigationShell.currentIndex;

        if (!loggedIn && branch == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) widget.navigationShell.goBranch(0);
          });
        }

        // 计算当前 display index
        int displayIndex = MobileShell._displayIndexForBranch(loggedIn, branch);

        // 保持 PageView 同步（用户通过底部栏点击切换时）
        if (!_isPageViewScrolling && _pageController.hasClients) {
          final currentPage = _pageController.page?.round() ?? 0;
          if (currentPage != displayIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients) {
                _pageController.jumpToPage(displayIndex);
              }
            });
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleBackPress(branch);
          },
          child: Scaffold(
            body: _TabBody(
              pageController: _pageController,
              tabCount: loggedIn ? 4 : 3,
              onPageChanged: _onPageViewChanged,
            ),
            bottomNavigationBar: _BottomNavBar(
              currentIndex: displayIndex,
              messageUnreadCount: messageUnreadCount,
              notificationUnreadCount: notificationUnreadCount,
              loggedIn: loggedIn,
              onTap: (index) => _switchToTab(index),
              slideAnim: _navSlideAnim,
            ),
          ),
        );
      },
    );
  }
}

/// PageView Tab 内容区
class _TabBody extends StatelessWidget {
  final PageController pageController;
  final int tabCount;
  final void Function(int) onPageChanged;

  const _TabBody({
    required this.pageController,
    required this.tabCount,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      itemCount: tabCount,
      physics: const BouncingScrollPhysics(),
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        // index: 0=首页 1=消息 2=校园(登录) 3=我的
        // 未登录: 0=首页 1=消息 2=我的
        switch (index) {
          case 0:
            return _HomeTabWrapper(tabCount: tabCount, pageController: pageController);
          case 1:
            return const MessagesPage();
          case 2:
            // 登录时显示校园，未登录时显示我的
            final loggedIn = AuthStore.instance.isAuthenticated;
            if (loggedIn) {
              return const XdyouHostPage();
            } else {
              return const ProfilePage();
            }
          case 3:
            return const ProfilePage();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// 首页 Tab：监听滚动方向以控制底部栏显隐 + overscroll 切换 Tab
class _HomeTabWrapper extends StatefulWidget {
  final int tabCount;
  final PageController pageController;

  const _HomeTabWrapper({
    required this.tabCount,
    required this.pageController,
  });

  @override
  State<_HomeTabWrapper> createState() => _HomeTabWrapperState();
}

class _HomeTabWrapperState extends State<_HomeTabWrapper> {
  bool _isScrollingDown = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta ?? 0;

          if (delta.abs() > 0.5) {
            if (delta > 0) {
              if (_isScrollingDown != true) {
                _isScrollingDown = true;
                BottomNavVisibilityNotifier.instance.show();
              }
            } else {
              if (_isScrollingDown != false) {
                _isScrollingDown = false;
                BottomNavVisibilityNotifier.instance.hide();
              }
            }
          }
          return false;
        }

        // Overscroll：向上快速滑过顶部时切换到上一个 Tab
        if (notification is OverscrollNotification) {
          if (notification.velocity < -200) {
            final currentPage = widget.pageController.page?.round() ?? 0;
            if (currentPage > 0) {
              widget.pageController.animateToPage(
                currentPage - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
          return true;
        }

        if (notification is ScrollStartNotification) {
          _isScrollingDown = false;
        }

        return false;
      },
      child: const HomePage(),
    );
  }
}

/// 底部导航栏（支持动画显隐）
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int messageUnreadCount;
  final int notificationUnreadCount;
  final bool loggedIn;
  final void Function(int) onTap;
  final Animation<double> slideAnim;

  const _BottomNavBar({
    required this.currentIndex,
    required this.messageUnreadCount,
    required this.notificationUnreadCount,
    required this.loggedIn,
    required this.onTap,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: slideAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, slideAnim.value),
          child: child,
        );
      },
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE8E8E8),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (loggedIn)
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: '首页',
                  isSelected: currentIndex == 0,
                  iconSize: 28,
                  onTap: () => onTap(0),
                ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble_rounded,
                label: '消息',
                isSelected: currentIndex == (loggedIn ? 1 : 0),
                iconSize: 28,
                badgeCount: messageUnreadCount,
                onTap: () => onTap(loggedIn ? 1 : 0),
              ),
              if (loggedIn)
                _NavItem(
                  icon: Icons.school_outlined,
                  selectedIcon: Icons.school_rounded,
                  label: '校园',
                  isSelected: currentIndex == 2,
                  iconSize: 28,
                  onTap: () => onTap(2),
                ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person_rounded,
                label: '我的',
                isSelected: currentIndex == (loggedIn ? 3 : 2),
                iconSize: 28,
                badgeCount: notificationUnreadCount,
                badgeIsNotification: true,
                onTap: () => onTap(loggedIn ? 3 : 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个导航项（图标 + 标签，28px 大图标，字重加粗）
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final double iconSize;
  final int badgeCount;
  final bool badgeIsNotification;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.iconSize,
    this.badgeCount = 0,
    this.badgeIsNotification = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? MobileTheme.primary : MobileTheme.textSecondary;

    Widget iconWidget = Icon(
      isSelected ? selectedIcon : icon,
      size: iconSize,
      color: color,
    );

    // 红点 Badge（右上角显示未读数）
    if (badgeCount > 0) {
      iconWidget = Badge(
        isLabelVisible: true,
        smallSize: 8,
        label: Text(
          badgeCount > 99 ? '99+' : badgeCount.toString(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
