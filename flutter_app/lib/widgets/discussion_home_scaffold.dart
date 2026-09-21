import 'package:flutter/material.dart';

import '../core/auth/auth_store.dart';
import '../core/l10n/ui_text.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../core/widgets/app_surfaces.dart';
import '../l10n/generated/app_localizations.dart';

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
    final desktop = AppBreakpoints.isDesktop(context);
    final width = MediaQuery.sizeOf(context).width;
    final scale = AppLayout.shellScale(width);
    final narrowPage = <int>{0, 1, 3, 4, 6}.contains(currentIndex);
    final colors = EditorialColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final actions = <_ShellAction>[
      _ShellAction(
        uiText(context, zh: '主页', en: 'Home'),
        Icons.home_outlined,
        () => onSelect(0),
        selected: currentIndex == 0,
      ),
      _ShellAction(
        l10n.search,
        Icons.search,
        onSearch,
        selected: currentIndex == 3,
      ),
      _ShellAction(
        l10n.campus,
        Icons.account_balance_outlined,
        () => onSelect(1),
        selected: currentIndex == 1,
      ),
      _ShellAction(
        l10n.notifications,
        Icons.notifications_none,
        onNotifications,
        badge: notificationUnreadCount,
        selected: currentIndex == 4,
      ),
      _ShellAction(
        l10n.conversations,
        Icons.chat_bubble_outline,
        onMessages,
        selected: currentIndex == 5,
      ),
      _ShellAction(
        'AI',
        Icons.auto_awesome_outlined,
        () => onSelect(2),
        selected: currentIndex == 2,
        star: true,
      ),
      _ShellAction(
        l10n.personalCenter,
        Icons.person_outline,
        onProfile,
        selected: currentIndex == 6,
      ),
      _ShellAction(
        l10n.settings,
        Icons.settings_outlined,
        onSettings,
        selected: currentIndex == 7,
      ),
    ];

    return Scaffold(
      key: const Key('discussion-ui-shell'),
      backgroundColor: colors.page,
      drawer: desktop
          ? null
          : Drawer(
              width: width * .73,
              backgroundColor: colors.page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(),
              child: SafeArea(
                child: _NavigationPanel(
                  actions: actions,
                  onCreate: onCreate,
                  onProfile: onProfile,
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
                builder: (context) => IconButton(
                  tooltip: uiText(context, zh: '打开导航', en: 'Open navigation'),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const _AccountAvatar(size: 29),
                ),
              ),
              title: const AppSealMark(size: 30),
              actions: <Widget>[
                if (currentIndex == 0)
                  IconButton(
                    tooltip: l10n.filter,
                    onPressed: onFilter,
                    icon: const Icon(Icons.tune),
                  ),
              ],
            ),
      body: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  key: const Key('desktop-primary-navigation'),
                  width: AppLayout.referenceRail * scale,
                  padding: EdgeInsets.only(
                    left: 123 * scale,
                    right: 24 * scale,
                  ),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: colors.line)),
                  ),
                  child: _NavigationPanel(
                    actions: actions,
                    onCreate: onCreate,
                    onProfile: onProfile,
                    scale: scale,
                  ),
                ),
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
                          left: narrowPage ? 61 * scale : 0,
                        ),
                        child: SizedBox(
                          width:
                              (narrowPage
                                  ? AppLayout.referenceFeed
                                  : AppLayout.referenceMain) *
                              scale,
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
              tooltip: l10n.createPost,
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
                      for (final action in <_ShellAction>[
                        actions[0],
                        actions[1],
                        actions[5],
                        actions[3],
                        actions[4],
                      ])
                        IconButton(
                          tooltip: action.label,
                          isSelected: action.selected,
                          onPressed: action.onTap,
                          icon: _ActionIcon(action: action, size: 27),
                          selectedIcon: _ActionIcon(action: action, size: 27),
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
    this.drawer = false,
    this.scale = 1,
  });

  final List<_ShellAction> actions;
  final VoidCallback onCreate;
  final VoidCallback onProfile;
  final bool drawer;
  final double scale;

  void _activate(BuildContext context, VoidCallback action) {
    if (drawer) Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: drawer
          ? const EdgeInsets.fromLTRB(29, 21, 29, 30)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (drawer)
            _DrawerAccount(onProfile: () => _activate(context, onProfile))
          else
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: actions.first.label,
                onPressed: () => _activate(context, actions.first.onTap),
                icon: AppSealMark(
                  size: drawer ? 34 : (40 * scale).clamp(28, 40),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final action in actions) ...<Widget>[
                  if (drawer && action.icon == Icons.settings_outlined)
                    const Padding(
                      padding: EdgeInsets.only(top: 28, bottom: 20),
                      child: Divider(),
                    ),
                  Semantics(
                    selected: action.selected,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: drawer ? 0 : 12 * scale,
                      ),
                      minTileHeight: drawer
                          ? 49
                          : (77.4 * scale).clamp(48, 77.4),
                      horizontalTitleGap: drawer ? 22 : 24 * scale,
                      leading: _ActionIcon(
                        action: action,
                        size: drawer ? 25 : (36 * scale).clamp(23, 36),
                      ),
                      title: Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: drawer
                              ? (action.icon == Icons.settings_outlined
                                    ? 17
                                    : 23)
                              : (30 * scale).clamp(17, 30),
                          fontWeight: drawer || action.selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      onTap: () => _activate(context, action.onTap),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('create-post-top-action'),
                  onPressed: () => _activate(context, onCreate),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: Size(
                      48,
                      drawer ? 48 : (80 * scale).clamp(48, 80),
                    ),
                  ),
                  child: Text(l10n.createPost),
                ),
              ],
            ),
          ),
          if (!drawer)
            ListenableBuilder(
              listenable: AuthStore.instance,
              builder: (context, _) {
                final nickname =
                    AuthStore.instance.currentUser?.nickname.trim() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const _AccountAvatar(size: 38),
                  title: Text(
                    nickname.isEmpty ? l10n.personalCenter : nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _activate(context, onProfile),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerAccount extends StatelessWidget {
  const _DrawerAccount({required this.onProfile});
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AuthStore.instance,
    builder: (context, _) {
      final user = AuthStore.instance.currentUser;
      final nickname = user?.nickname.trim() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                InkWell(
                  onTap: onProfile,
                  child: const _AccountAvatar(size: 38),
                ),
                const Spacer(),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 9),
            InkWell(
              onTap: onProfile,
              child: Text(
                nickname.isEmpty
                    ? AppLocalizations.of(context)!.personalCenter
                    : nickname,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (user != null) ...<Widget>[
              const SizedBox(height: 13),
              Text(
                uiText(
                  context,
                  zh: '${user.followingCount} 关注  ${user.followerCount} 关注者',
                  en: '${user.followingCount} Following  ${user.followerCount} Followers',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 16),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AuthStore.instance,
    builder: (context, _) {
      final user = AuthStore.instance.currentUser;
      final nickname = user?.nickname.trim() ?? '';
      final url = user?.avatarUrl.trim() ?? '';
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundImage: url.isEmpty ? null : NetworkImage(url),
        child: url.isNotEmpty
            ? null
            : Text(
                nickname.isEmpty
                    ? uiText(context, zh: '匿', en: 'A')
                    : nickname.characters.first,
                style: TextStyle(fontSize: size * .45),
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
    final colors = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: action.badge > 0,
      backgroundColor: colors.onSurface,
      textColor: colors.surface,
      label: Text(action.badge > 99 ? '99+' : '${action.badge}'),
      child: action.star
          ? CustomPaint(
              size: Size.square(size),
              painter: _StarPainter(colors.onSurface),
            )
          : Icon(
              action.selected && action.icon == Icons.home_outlined
                  ? Icons.home
                  : action.icon,
              size: size,
              color: colors.onSurface,
            ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
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
