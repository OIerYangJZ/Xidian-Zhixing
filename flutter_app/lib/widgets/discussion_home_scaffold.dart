import 'package:flutter/material.dart';

import '../core/auth/auth_store.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';

class DiscussionHomeScaffold extends StatelessWidget {
  const DiscussionHomeScaffold({
    super.key,
    required this.currentIndex,
    required this.content,
    required this.notificationUnreadCount,
    required this.onSelect,
    required this.onCreate,
    required this.onFilter,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onSettings,
    required this.onProfile,
  });

  final int currentIndex;
  final Widget content;
  final int notificationUnreadCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onFilter;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double width = MediaQuery.sizeOf(context).width;
    final double scale = AppLayout.shellScale(width);
    final EditorialColors colors = EditorialColors.of(context);
    final List<_ShellAction> actions = <_ShellAction>[
      _ShellAction(
        '主页',
        Icons.home_outlined,
        () => onSelect(0),
        selected: currentIndex == 0,
      ),
      _ShellAction('探索', Icons.search, onSearch, selected: currentIndex == 3),
      _ShellAction(
        '校园',
        Icons.account_balance_outlined,
        () => onSelect(1),
        selected: currentIndex == 1,
      ),
      _ShellAction(
        '通知',
        Icons.notifications_none,
        onNotifications,
        badge: notificationUnreadCount,
        selected: currentIndex == 4,
      ),
      _ShellAction(
        '关注',
        Icons.person_add_alt_1_outlined,
        () => onSelect(5),
        selected: currentIndex == 5,
      ),
      _ShellAction(
        '聊天',
        Icons.chat_bubble_outline,
        onMessages,
        selected: currentIndex == 6,
      ),
      _ShellAction(
        'AI',
        Icons.auto_awesome_outlined,
        () => onSelect(2),
        selected: currentIndex == 2,
        star: true,
      ),
      _ShellAction(
        '历史',
        Icons.bookmark_border,
        () => onSelect(7),
        selected: currentIndex == 7,
      ),
      _ShellAction(
        '个人资料',
        Icons.person_outline,
        onProfile,
        selected: currentIndex == 8,
      ),
    ];

    return Scaffold(
      key: const Key('discussion-ui-shell'),
      backgroundColor: colors.page,
      drawer: desktop
          ? null
          : Drawer(
              width: width * .78,
              backgroundColor: colors.page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(),
              child: SafeArea(
                child: _NavigationPanel(
                  actions: actions,
                  onCreate: onCreate,
                  onProfile: onProfile,
                  onSettings: onSettings,
                  drawer: true,
                ),
              ),
            ),
      appBar: desktop
          ? null
          : AppBar(
              toolbarHeight: 60,
              centerTitle: true,
              leading: Builder(
                builder: (BuildContext context) => IconButton(
                  tooltip: '打开导航',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const _AccountAvatar(size: 29),
                ),
              ),
              title: const Icon(Icons.bolt, size: 30),
              actions: <Widget>[
                if (currentIndex == 0)
                  IconButton(onPressed: onFilter, icon: const Icon(Icons.tune)),
              ],
            ),
      body: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  key: const Key('desktop-primary-navigation'),
                  width: AppLayout.referenceRail * scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: colors.line)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: 123 * scale),
                      child: _NavigationPanel(
                        actions: actions,
                        onCreate: onCreate,
                        onProfile: onProfile,
                        onSettings: onSettings,
                        scale: scale,
                      ),
                    ),
                  ),
                ),
                if (currentIndex == 9)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 61 * scale),
                      child: content,
                    ),
                  )
                else
                  SizedBox(
                    width: AppLayout.referenceMain * scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: colors.line)),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left:
                                <int>{
                                  0,
                                  1,
                                  3,
                                  4,
                                  5,
                                  7,
                                  8,
                                }.contains(currentIndex)
                                ? 61 * scale
                                : 0,
                          ),
                          child: SizedBox(
                            width:
                                <int>{
                                  0,
                                  1,
                                  3,
                                  4,
                                  5,
                                  7,
                                  8,
                                }.contains(currentIndex)
                                ? AppLayout.referenceFeed * scale
                                : AppLayout.referenceMain * scale,
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : content,
      floatingActionButton: !desktop && currentIndex == 0
          ? FloatingActionButton(
              key: const Key('create-post-fab'),
              onPressed: onCreate,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  key: const Key('mobile-primary-navigation'),
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      for (final _ShellAction action in <_ShellAction>[
                        actions[0],
                        actions[1],
                        actions[6],
                        actions[3],
                        actions[5],
                      ])
                        IconButton(
                          onPressed: action.onTap,
                          tooltip: action.label,
                          icon: _ActionIcon(action: action, size: 27),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.actions,
    required this.onCreate,
    required this.onProfile,
    required this.onSettings,
    this.drawer = false,
    this.scale = 1,
  });

  final List<_ShellAction> actions;
  final VoidCallback onCreate;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final bool drawer;
  final double scale;

  void _activate(BuildContext context, VoidCallback action) {
    if (drawer) Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final double navScale = drawer ? 1 : scale;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: drawer
          ? const EdgeInsets.fromLTRB(29, 21, 29, 30)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 83 * navScale,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _activate(context, actions.first.onTap),
                icon: Icon(Icons.bolt, size: 41 * navScale, color: ink),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: drawer ? 0 : 5 * navScale),
              children: <Widget>[
                for (final _ShellAction action in actions)
                  _ReferenceNavItem(
                    action: action,
                    scale: navScale,
                    onTap: () => _activate(context, action.onTap),
                  ),
                SizedBox(height: 10 * navScale),
                SizedBox(
                  width: 322 * navScale,
                  height: 80 * navScale,
                  child: FilledButton(
                    key: const Key('create-post-top-action'),
                    onPressed: () => _activate(context, onCreate),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      shape: const StadiumBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '发布',
                      style: TextStyle(
                        fontSize: 27 * navScale,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                if (drawer) ...<Widget>[
                  const SizedBox(height: 28),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('设置'),
                    onTap: () => _activate(context, onSettings),
                  ),
                ],
              ],
            ),
          ),
          if (!drawer)
            ListenableBuilder(
              listenable: AuthStore.instance,
              builder: (BuildContext context, Widget? child) {
                final String nickname =
                    AuthStore.instance.currentUser?.nickname.trim() ?? '';
                return Padding(
                  padding: EdgeInsets.only(
                    left: 18 * navScale,
                    bottom: 33 * navScale,
                  ),
                  child: InkWell(
                    onTap: onProfile,
                    child: SizedBox(
                      width: 321 * navScale,
                      child: Row(
                        children: <Widget>[
                          _AccountAvatar(size: 61 * navScale),
                          SizedBox(width: 17 * navScale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  nickname.isEmpty ? '个人资料' : nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24 * navScale,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                Text(
                                  '@${nickname.isEmpty ? 'Xaverll' : nickname}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24 * navScale,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onSettings,
                            child: Text(
                              '···',
                              style: TextStyle(
                                fontSize: 26 * navScale,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReferenceNavItem extends StatelessWidget {
  const _ReferenceNavItem({
    required this.action,
    required this.scale,
    required this.onTap,
  });
  final _ShellAction action;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final EditorialColors colors = EditorialColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 77.4 * scale,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(42 * scale),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: action.selected
                  ? colors.primarySubtle
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(42 * scale),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 19 * scale),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 39 * scale,
                    height: 39 * scale,
                    child: Center(
                      child: _ActionIcon(action: action, size: 36 * scale),
                    ),
                  ),
                  SizedBox(width: 32 * scale),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 30 * scale,
                      height: 1,
                      fontWeight: action.selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AuthStore.instance,
    builder: (BuildContext context, Widget? child) {
      final user = AuthStore.instance.currentUser;
      final String nickname = user?.nickname.trim() ?? '';
      final String url = user?.avatarUrl.trim() ?? '';
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundImage: url.isEmpty ? null : NetworkImage(url),
        child: url.isNotEmpty
            ? null
            : Text(
                nickname.isEmpty ? '匿' : nickname.characters.first,
                style: TextStyle(fontSize: size * .42),
              ),
      );
    },
  );
}

class _ShellAction {
  const _ShellAction(
    this.label,
    this.icon,
    this.onTap, {
    this.selected = false,
    this.badge = 0,
    this.star = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final int badge;
  final bool star;
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action, required this.size});
  final _ShellAction action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurface;
    final Widget icon = action.star
        ? CustomPaint(size: Size.square(size), painter: _StarPainter(color))
        : Icon(
            action.selected && action.icon == Icons.home_outlined
                ? Icons.home
                : action.icon,
            size: size,
            color: color,
          );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        icon,
        if (action.badge > 0)
          Positioned(
            right: -6,
            top: -9,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF91880),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1,
                ),
              ),
              child: Text(
                action.badge > 99 ? '99+' : '${action.badge}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Arial',
                  fontSize: 18,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(12, 2)
      ..lineTo(15, 9)
      ..lineTo(22, 12)
      ..lineTo(15, 15)
      ..lineTo(12, 22)
      ..lineTo(9, 15)
      ..lineTo(2, 12)
      ..lineTo(9, 9)
      ..close();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}
