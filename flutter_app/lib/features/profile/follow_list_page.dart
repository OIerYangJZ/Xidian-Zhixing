import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/follow_user_item.dart';
import '../../repositories/app_repositories.dart';
import 'public_user_profile_page.dart';

enum FollowListTab { following, followers, friends }

/// 关注与粉丝: 关注 / 粉丝 / 好友, each row opening the user's profile and
/// with its own follow button.
class FollowListPage extends StatefulWidget {
  const FollowListPage({super.key, this.initialTab = FollowListTab.following});

  final FollowListTab initialTab;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final Map<FollowListTab, List<FollowUserItem>> _lists =
      <FollowListTab, List<FollowUserItem>>{};
  final Map<FollowListTab, String> _errors = <FollowListTab, String>{};
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    for (final FollowListTab tab in FollowListTab.values) {
      _load(tab);
    }
  }

  Future<void> _load(FollowListTab tab) async {
    setState(() => _errors.remove(tab));
    try {
      final List<FollowUserItem> items = await switch (tab) {
        FollowListTab.following => AppRepositories.users.fetchFollowing(),
        FollowListTab.followers => AppRepositories.users.fetchFollowers(),
        FollowListTab.friends => AppRepositories.users.fetchFriends(),
      };
      if (mounted) setState(() => _lists[tab] = items);
    } catch (error) {
      if (mounted) setState(() => _errors[tab] = '$error');
    }
  }

  Future<void> _toggleFollow(FollowUserItem user) async {
    setState(() => _busy.add(user.userId));
    try {
      if (user.isFollowing) {
        await AppRepositories.users.unfollowUser(user.userId);
      } else {
        await AppRepositories.users.followUser(user.userId);
      }
      await Future.wait(FollowListTab.values.map(_load));
    } catch (error) {
      if (mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '操作失败：$error', en: 'Action failed: $error'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    String label(FollowListTab tab, String zh, String en) {
      final int? count = _lists[tab]?.length;
      return count == null ? text(zh, en) : '${text(zh, en)} $count';
    }

    return DefaultTabController(
      length: FollowListTab.values.length,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(text('关注与粉丝', 'Following and followers')),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: label(FollowListTab.following, '关注', 'Following')),
              Tab(text: label(FollowListTab.followers, '粉丝', 'Followers')),
              Tab(text: label(FollowListTab.friends, '好友', 'Friends')),
            ],
          ),
        ),
        body: ZxPaper(
          child: TabBarView(
            children: <Widget>[
              for (final FollowListTab tab in FollowListTab.values)
                _buildList(tab),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(FollowListTab tab) {
    final List<FollowUserItem>? items = _lists[tab];
    final String? error = _errors[tab];
    if (error != null && items == null) {
      return ZxStatePanel(
        icon: Icons.error_outline_rounded,
        error: true,
        title: uiText(context, zh: '列表加载失败', en: 'Could not load the list'),
        message: error,
        actionLabel: uiText(context, zh: '重试', en: 'Retry'),
        onAction: () => _load(tab),
      );
    }
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ZxStatePanel(
        icon: Icons.people_outline_rounded,
        title: switch (tab) {
          FollowListTab.following => uiText(
            context,
            zh: '还没有关注任何人',
            en: 'Not following anyone yet',
          ),
          FollowListTab.followers => uiText(
            context,
            zh: '还没有粉丝',
            en: 'No followers yet',
          ),
          FollowListTab.friends => uiText(
            context,
            zh: '还没有好友',
            en: 'No friends yet',
          ),
        },
        message: tab == FollowListTab.friends
            ? uiText(
                context,
                zh: '互相关注的同学会出现在这里',
                en: 'People you follow who follow you back show here.',
              )
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(tab),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ZxCard(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++) ...<Widget>[
                      if (i > 0)
                        Divider(height: 1, color: ZxTokens.of(context).line),
                      _row(items[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(FollowUserItem user) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final bool busy = _busy.contains(user.userId);
    return InkWell(
      borderRadius: ZxRadius.buttonAll,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicUserProfilePage(userId: user.userId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            ZxAvatar(
              name: user.nicknameFor(locale),
              imageUrl: user.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.nicknameFor(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZxType.label.copyWith(color: t.text),
              ),
            ),
            const SizedBox(width: 8),
            ZxButton(
              label: user.isMutual
                  ? uiText(context, zh: '互相关注', en: 'Mutual')
                  : user.isFollowing
                  ? uiText(context, zh: '已关注', en: 'Following')
                  : user.isFollower
                  ? uiText(context, zh: '回关', en: 'Follow back')
                  : uiText(context, zh: '关注', en: 'Follow'),
              variant: user.isFollowing
                  ? ZxButtonVariant.secondary
                  : ZxButtonVariant.primary,
              small: true,
              loading: busy,
              onPressed: busy ? null : () => _toggleFollow(user),
            ),
          ],
        ),
      ),
    );
  }
}
