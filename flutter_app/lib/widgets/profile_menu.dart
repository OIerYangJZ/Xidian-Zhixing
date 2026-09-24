import 'package:flutter/material.dart';

import '../core/auth/auth_store.dart';
import '../core/l10n/ui_text.dart';
import '../core/state/app_locale_store.dart';
import '../design_system/design_system.dart';
import '../features/auth/login_page.dart';
import '../features/me/my_favorites_page.dart';
import '../features/me/my_posts_page.dart';
import '../features/messages/messages_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/settings_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_profile.dart';
import '../repositories/app_repositories.dart';

/// The account menu opened from the profile block or the narrow top bar's
/// avatar (handoff W2): 个人资料与设置 · 我的帖子 · 我的收藏 · 会话 · 设置,
/// the language switch, and 退出登录. A popover beside the sidebar on wide
/// screens, a bottom sheet otherwise.
Future<void> showProfileMenu(BuildContext context, {required bool wide}) {
  if (!wide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _ProfileMenu(),
        ),
      ),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    pageBuilder: (BuildContext dialogContext, _, _) => const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        // Sits just above the profile block at the foot of the sidebar.
        padding: EdgeInsets.fromLTRB(14, 0, 0, 84),
        child: SizedBox(
          width: 280,
          child: ZxCard(
            elevation: ZxElevation.overlay,
            padding: EdgeInsets.all(8),
            child: _ProfileMenu(),
          ),
        ),
      ),
    ),
  );
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final UserProfile? user = AuthStore.instance.currentUser;
    final String nickname = user?.nickname.trim() ?? '';
    final String status = <String>[
      if (user?.verified ?? false) uiText(context, zh: '已认证', en: 'Verified'),
      if ((user?.userLevel ?? 0) > 0) 'Lv.${user!.userLevel}',
    ].join(' · ');

    void open(Widget page) {
      final NavigatorState navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute<void>(builder: (_) => page));
    }

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Row(
              children: <Widget>[
                ZxAvatar(
                  name: nickname.isEmpty
                      ? uiText(context, zh: '我', en: 'Me')
                      : nickname,
                  imageUrl: user?.avatarUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        nickname.isEmpty ? l10n.personalCenter : nickname,
                        style: ZxType.label.copyWith(color: t.text),
                      ),
                      if (status.isNotEmpty)
                        Text(
                          status,
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 4),
          ZxListItem(
            icon: Icons.person_outline_rounded,
            title: l10n.profileAndSettings,
            onTap: () => open(const ProfilePage()),
          ),
          ZxListItem(
            icon: Icons.edit_note_rounded,
            title: uiText(context, zh: '我的帖子', en: 'My posts'),
            onTap: () => open(const MyPostsPage()),
          ),
          ZxListItem(
            icon: Icons.star_outline_rounded,
            iconColor: t.accentInk,
            title: uiText(context, zh: '我的收藏', en: 'Saved posts'),
            onTap: () => open(const MyFavoritesPage()),
          ),
          ZxListItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.conversations,
            onTap: () => open(const MessagesPage()),
          ),
          ZxListItem(
            icon: Icons.tune_rounded,
            title: l10n.settings,
            onTap: () => open(const SettingsPage()),
          ),
          ZxListItem(
            icon: Icons.language_rounded,
            title: uiText(context, zh: '语言', en: 'Language'),
            trailing: const _LanguageSwitch(),
            showChevron: false,
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 4),
          ZxListItem(
            key: const Key('profile-menu-logout'),
            icon: Icons.logout_rounded,
            title: uiText(context, zh: '退出登录', en: 'Log out'),
            danger: true,
            showChevron: false,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    try {
      await AppRepositories.auth.logout();
    } catch (error) {
      if (context.mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '退出失败：$error', en: 'Log out failed: $error'),
        );
      }
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }
}

/// 中 / EN, applied at once.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('中')),
        ButtonSegment<bool>(value: true, label: Text('EN')),
      ],
      selected: <bool>{english},
      onSelectionChanged: (Set<bool> value) =>
          AppLocaleStore.instance.setLocale(
            value.first ? const Locale('en') : const Locale('zh', 'CN'),
          ),
    );
  }
}
