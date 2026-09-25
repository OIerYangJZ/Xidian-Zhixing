import 'package:flutter/material.dart';

import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../shell/mobile_shell.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/models/follow_user_item.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';

/// 个人主页 — Twitter/Instagram 混合风格
/// 无卡片、无圆角、紧凑信息流布局
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  UserProfile? _profile;
  List<FollowUserItem> _followers = [];
  List<FollowUserItem> _following = [];
  bool _profileLoading = true;
  bool _followLoading = true;
  String? _profileError;
  String? _followError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfile();
    _loadFollowData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final delta = _scrollController.position.pixels - _lastScrollOffset;
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }
    _lastScrollOffset = _scrollController.position.pixels;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final profile = await repo.fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileError = error.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadFollowData() async {
    setState(() {
      _followLoading = true;
      _followError = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final results = await Future.wait([
        repo.fetchFollowers(),
        repo.fetchFollowing(),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _following = results[1];
        _followLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _followLoading = false;
        _followError = error.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showFollowSheet(String title, List<FollowUserItem> users) {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FollowListSheet(title: title, users: users),
    );
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) {
      _loadProfile();
      _loadFollowData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final UserProfile? p = _profile;
    final bool admin = p?.isAdmin ?? false;
    final String school = <String>[
      p?.college ?? '',
      p?.major ?? '',
    ].where((String s) => s.trim().isNotEmpty).join(' · ');

    // Handoff A4. 热榜 / 学院专区 / 社团 join the menu when Android has them.
    return Scaffold(
      backgroundColor: t.bg,
      body: RefreshIndicator(
        color: t.primary,
        onRefresh: () async {
          await Future.wait([_loadProfile(), _loadFollowData()]);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ZxHeroWash(
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: 10,
                      child: IgnorePointer(
                        child: Text(
                          '知',
                          style: TextStyle(
                            fontFamily: ZxFonts.display,
                            fontFamilyFallback: ZxFonts.displayFallback,
                            fontSize: 150,
                            height: 1,
                            color: t.primary.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              key: const Key('mobile-profile-settings'),
                              tooltip: '设置',
                              icon: Icon(Icons.tune_rounded, color: t.text2),
                              onPressed: () => _open('/profile/settings'),
                            ),
                          ),
                          if (_profileError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ZxInlineMessage(
                                message: _profileError!,
                                tone: ZxMessageTone.danger,
                                actionLabel: '重试',
                                onAction: _loadProfile,
                              ),
                            ),
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: t.surface,
                                    width: 3,
                                  ),
                                ),
                                child: ZxAvatar(
                                  name: p?.nickname ?? '我',
                                  imageUrl: p?.avatarUrl,
                                  size: 72,
                                  onTap: () => _open('/profile/edit'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          _profileLoading && p == null
                                              ? ''
                                              : (p?.nickname ?? '匿名同学'),
                                          style: ZxType.headline.copyWith(
                                            color: t.text,
                                          ),
                                        ),
                                        if (p?.verified ?? false)
                                          const ZxBadge.verified('已认证'),
                                      ],
                                    ),
                                    if (school.isNotEmpty)
                                      Text(
                                        school,
                                        style: ZxType.caption.copyWith(
                                          fontSize: 13,
                                          color: t.text2,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _Count(
                                value: _followLoading || _followError != null
                                    ? '–'
                                    : '${_followers.length}',
                                label: '粉丝',
                                onTap: () => _showFollowSheet('粉丝', _followers),
                              ),
                              const SizedBox(width: 18),
                              _Count(
                                value: _followLoading || _followError != null
                                    ? '–'
                                    : '${_following.length}',
                                label: '关注',
                                onTap: () => _showFollowSheet('关注', _following),
                              ),
                              const SizedBox(width: 14),
                              ZxBadge.level(
                                'Lv.${(p?.isLevelOneUser ?? false) ? 1 : (p?.userLevel ?? 2)}',
                              ),
                              const Spacer(),
                              ZxButton(
                                key: const Key('mobile-profile-edit'),
                                label: '编辑资料',
                                variant: ZxButtonVariant.secondary,
                                small: true,
                                onPressed: () => _open('/profile/edit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ZxCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _Quick(
                      icon: Icons.edit_outlined,
                      hue: t.primary,
                      label: '我的发布',
                      onTap: () => _open('/profile/posts'),
                    ),
                    _Quick(
                      icon: Icons.chat_bubble_outline_rounded,
                      hue: t.info,
                      label: '我的评论',
                      onTap: () => _open('/profile/comments'),
                    ),
                    _Quick(
                      icon: Icons.star_outline_rounded,
                      hue: t.accentInk,
                      label: '我的收藏',
                      onTap: () => _open('/favorites'),
                    ),
                    _Quick(
                      icon: Icons.flag_outlined,
                      hue: t.seal,
                      label: '我的举报',
                      onTap: () => _open('/profile/reports'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ZxListSection(
                children: [
                  ZxListItem(
                    icon: Icons.mail_outline_rounded,
                    iconColor: t.accentInk,
                    title: '信箱',
                    subtitle: '帮助与反馈',
                    onTap: () => _open('/profile/help-feedback'),
                  ),
                  if (admin)
                    ZxListItem(
                      icon: Icons.shield_outlined,
                      iconColor: t.text2,
                      title: '管理',
                      trailing: const ZxBadge.level('仅管理员'),
                      showChevron: true,
                      onTap: () => _open('/admin'),
                    ),
                  ZxListItem(
                    icon: Icons.tune_rounded,
                    iconColor: t.text2,
                    title: '设置',
                    subtitle: '账号 · 隐私 · 通知 · 外观',
                    onTap: () => _open('/profile/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: ZxType.title.copyWith(color: t.text),
            ),
            TextSpan(
              text: label,
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.hue,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color hue;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: ZxRadius.buttonAll,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Color.lerp(hue, t.surface, 0.86),
                borderRadius: ZxRadius.buttonAll,
              ),
              child: Icon(icon, size: 20, color: hue),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: ZxType.caption.copyWith(
                color: t.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowListSheet extends StatelessWidget {
  final String title;
  final List<FollowUserItem> users;

  const _FollowListSheet({required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final mutual = users.where((u) => u.isMutual).toList();
    final others = users.where((u) => !u.isMutual).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${users.length}',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 0.5, color: colors.divider),
            // 列表
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      children: [
                        if (mutual.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              '好友',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          ...mutual.map((u) => _FollowUserTile(user: u)),
                          if (others.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                '其他',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                        ...others.map((u) => _FollowUserTile(user: u)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowUserTile extends StatelessWidget {
  final FollowUserItem user;

  const _FollowUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: AvatarWidget(
        avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
        nickname: user.nickname,
        radius: 20,
      ),
      title: Text(
        user.nickname,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      trailing: user.isMutual
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MobileTheme.primaryWithAlpha(context, 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '好友',
                style: TextStyle(
                  fontSize: 12,
                  color: MobileTheme.primaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}

/// 我的帖子 Tab — 真实数据
