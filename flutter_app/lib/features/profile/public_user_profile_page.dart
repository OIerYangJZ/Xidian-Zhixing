import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/navigation/share_links.dart';
import '../../core/state/app_providers.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../messages/chat_page.dart';
import '../post/report_dialog.dart';

/// Someone else's profile (handoff U1–U4): the card with 私信 / 关注 / ⋯,
/// TA 的帖子, and 关于 TA beside them on wide screens. ⋯ copies the link,
/// blocks and reports. Once blocked, only 解除屏蔽 remains.
class PublicUserProfilePage extends ConsumerStatefulWidget {
  const PublicUserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicUserProfilePage> createState() =>
      _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends ConsumerState<PublicUserProfilePage> {
  PublicUserProfile? _profile;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<PostItem>? _posts;
  String? _postsError;
  PostSort _sort = PostSort.latest;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
  }

  Future<void> _loadPosts() async {
    setState(() => _postsError = null);
    try {
      final List<PostItem> posts = await AppRepositories.posts.fetchUserPosts(
        widget.userId,
      );
      if (mounted) setState(() => _posts = posts);
    } catch (error) {
      if (mounted) setState(() => _postsError = '$error');
    }
  }

  Future<void> _setBlocked(bool block) async {
    final PublicUserProfile? profile = _profile;
    if (profile == null || _busy) return;
    if (block) {
      final bool confirmed = await zxConfirm(
        context,
        title: uiText(context, zh: '屏蔽 TA？', en: 'Block this user?'),
        message: uiText(
          context,
          zh: '屏蔽后不再看到 TA 的帖子，也不会收到 TA 的私信。可以在「设置 → 黑名单管理」解除。',
          en:
              'You will stop seeing their posts and messages. Undo it in '
              'Blocked accounts.',
        ),
        confirmLabel: uiText(context, zh: '屏蔽', en: 'Block'),
        cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      if (block) {
        await repo.blockUser(profile.id);
      } else {
        await repo.unblockUser(profile.id);
      }
      if (!mounted) return;
      _feedback(
        block
            ? uiText(context, zh: '已屏蔽', en: 'Blocked')
            : uiText(context, zh: '已解除屏蔽', en: 'Unblocked'),
      );
      // Follow and message rights change with the block; reload them.
      await _loadProfile();
    } catch (error) {
      _feedback(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null) return;
    final ReportChoice? choice = await showReportDialog(context);
    if (choice == null || !mounted) return;
    try {
      await AppRepositories.posts.report(
        targetType: 'user',
        targetId: profile.id,
        reason: choice.reason,
        description: choice.description,
      );
      _feedback(
        uiTextGlobal(zh: '举报已提交，感谢反馈', en: 'Report submitted, thank you'),
      );
    } catch (error) {
      _feedback(uiTextGlobal(zh: '举报失败：$error', en: 'Report failed: $error'));
    }
  }

  Future<void> _openMore() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null) return;
    final String? action = await zxShowActionSheet<String>(
      context,
      actions: <ZxSheetAction<String>>[
        ZxSheetAction<String>(
          value: 'link',
          label: uiText(context, zh: '复制主页链接', en: 'Copy profile link'),
          icon: Icons.link_rounded,
        ),
        if (profile.canFollow)
          ZxSheetAction<String>(
            value: profile.isBlockedByMe ? 'unblock' : 'block',
            label: profile.isBlockedByMe
                ? uiText(context, zh: '解除屏蔽', en: 'Unblock')
                : uiText(context, zh: '屏蔽', en: 'Block'),
            icon: Icons.block_rounded,
          ),
        if (profile.canFollow)
          ZxSheetAction<String>(
            value: 'report',
            label: uiText(context, zh: '举报', en: 'Report'),
            icon: Icons.flag_outlined,
            danger: true,
          ),
      ],
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
    );
    switch (action) {
      case 'link':
        await _copyProfileLink();
      case 'block':
        await _setBlocked(true);
      case 'unblock':
        await _setBlocked(false);
      case 'report':
        await _report();
    }
  }

  Future<void> _openPost(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) return;
    setState(() {
      _posts = _posts
          ?.map((PostItem p) => p.id == updated.id ? updated : p)
          .toList();
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final PublicUserProfile profile = await ref
          .read(userRepositoryProvider)
          .fetchUserProfile(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
      });
      if (!profile.isBlockedByMe) _loadPosts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null || _busy || !profile.canFollow || profile.id.isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      if (profile.isFollowing) {
        await repo.unfollowUser(profile.id);
      } else {
        await repo.followUser(profile.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile.copyWith(
          isFollowing: !profile.isFollowing,
          followerCount: profile.isFollowing
              ? (profile.followerCount > 0 ? profile.followerCount - 1 : 0)
              : profile.followerCount + 1,
        );
      });
      _feedback(
        profile.isFollowing
            ? uiTextGlobal(zh: '已取消关注', en: 'Unfollowed')
            : uiTextGlobal(zh: '关注成功', en: 'Following'),
      );
    } catch (error) {
      _feedback(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleDm() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null || profile.id.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final conversation = await AppRepositories.messages
          .createDirectConversation(profile.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatPage(conversation: conversation, peerUserId: profile.id),
        ),
      );
    } catch (error) {
      _feedback(
        uiTextGlobal(
          zh: '无法发起私信：$error',
          en: 'Could not start a direct message: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _copyProfileLink() async {
    await Clipboard.setData(
      ClipboardData(text: ShareLink.user(widget.userId).url),
    );
    if (!mounted) return;
    zxShowToast(
      context,
      uiText(context, zh: '已复制主页链接', en: 'Profile link copied'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PublicUserProfile? profile = _profile;
    Widget body;
    if (_loading && profile == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (profile == null) {
      body = ZxStatePanel(
        icon: Icons.person_off_outlined,
        error: _error != null,
        title: uiText(context, zh: '无法显示个人主页', en: 'Profile unavailable'),
        message:
            _error ??
            uiText(
              context,
              zh: '该用户不存在，或主页当前不可访问。',
              en: 'This user does not exist, or the profile is currently unavailable.',
            ),
        actionLabel: _error == null
            ? null
            : uiText(context, zh: '重试', en: 'Retry'),
        onAction: _error == null ? null : _loadProfile,
      );
    } else {
      body = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool wide = c.maxWidth >= 1100;
          final Widget posts = _buildPosts(profile);
          return RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1040 : 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildHero(profile, wide: wide),
                        const SizedBox(height: 18),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: posts),
                              const SizedBox(width: 20),
                              SizedBox(width: 280, child: _buildAbout(profile)),
                            ],
                          )
                        else
                          posts,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile == null
              ? uiText(context, zh: '个人主页', en: 'Profile')
              : profile.nicknameFor(Localizations.localeOf(context)),
        ),
        actions: <Widget>[
          if (profile != null)
            IconButton(
              key: const Key('public-profile-more'),
              tooltip: uiText(context, zh: '更多', en: 'More'),
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: _openMore,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ZxPaper(child: body),
    );
  }

  Widget _buildHero(PublicUserProfile profile, {required bool wide}) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String background = AppConfig.resolveUrl(profile.backgroundImageUrl);
    final List<String> meta = <String>[
      if (profile.college.trim().isNotEmpty) profile.college.trim(),
      if (profile.major.trim().isNotEmpty) profile.major.trim(),
      if (profile.gender.trim().isNotEmpty) profile.genderFor(locale).trim(),
    ];
    final Widget actions = profile.isBlockedByMe
        ? ZxButton(
            key: const Key('public-profile-unblock'),
            label: uiText(context, zh: '解除屏蔽', en: 'Unblock'),
            icon: Icons.block_rounded,
            variant: ZxButtonVariant.secondary,
            small: true,
            onPressed: _busy ? null : () => _setBlocked(false),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (profile.canDirectMessage) ...<Widget>[
                ZxButton(
                  key: const Key('public-profile-dm'),
                  label: uiText(context, zh: '私信', en: 'Message'),
                  icon: Icons.chat_bubble_outline_rounded,
                  variant: ZxButtonVariant.secondary,
                  small: true,
                  onPressed: _busy ? null : _handleDm,
                ),
                const SizedBox(width: 8),
              ],
              if (profile.canFollow)
                ZxButton(
                  key: const Key('public-profile-follow'),
                  label: profile.isFollowing && profile.isFollower
                      ? uiText(context, zh: '互相关注', en: 'Mutual')
                      : profile.isFollowing
                      ? uiText(context, zh: '已关注', en: 'Following')
                      : profile.isFollower
                      ? uiText(context, zh: '回关', en: 'Follow back')
                      : uiText(context, zh: '关注', en: 'Follow'),
                  icon: profile.isFollowing ? null : Icons.add_rounded,
                  variant: profile.isFollowing
                      ? ZxButtonVariant.secondary
                      : ZxButtonVariant.primary,
                  small: true,
                  onPressed: _busy ? null : _toggleFollow,
                ),
            ],
          );
    return ZxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ZxRadius.card),
            ),
            child: SizedBox(
              height: wide ? 180 : 120,
              child: background.isEmpty
                  ? ZxHeroWash(child: const SizedBox.expand())
                  : Image.network(
                      background,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ZxHeroWash(child: const SizedBox.expand()),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.surface, width: 4),
                        ),
                        child: ZxAvatar(
                          name: profile.nicknameFor(locale),
                          imageUrl: profile.avatarUrl,
                          size: 76,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: actions,
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            profile.nicknameFor(locale),
                            style: ZxType.headline.copyWith(color: t.text),
                          ),
                          if (profile.userLevelLabel.trim().isNotEmpty)
                            ZxBadge.level(profile.userLevelLabelFor(locale)),
                          if (profile.isBlockedByMe)
                            ZxBadge.blocked(
                              uiText(context, zh: '已屏蔽', en: 'Blocked'),
                            ),
                        ],
                      ),
                      if (profile.bio.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          profile.bio.trim(),
                          style: ZxType.body.copyWith(color: t.text2),
                        ),
                      ],
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          meta.join('  ·  '),
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 18,
                        children: <Widget>[
                          _Count(
                            value: profile.postCount,
                            label: uiText(context, zh: '帖子', en: 'posts'),
                          ),
                          _Count(
                            value: profile.followingCount,
                            label: uiText(context, zh: '关注', en: 'following'),
                          ),
                          _Count(
                            value: profile.followerCount,
                            label: uiText(context, zh: '粉丝', en: 'followers'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts(PublicUserProfile profile) {
    final ZxTokens t = ZxTokens.of(context);
    if (profile.isBlockedByMe) {
      return Padding(
        key: const Key('public-profile-blocked'),
        padding: const EdgeInsets.only(top: 40),
        child: ZxStatePanel(
          icon: Icons.block_rounded,
          title: uiText(context, zh: '你已屏蔽 TA', en: 'You blocked this user'),
          message: uiText(
            context,
            zh: '不显示 TA 的帖子。解除屏蔽后恢复。',
            en: 'Their posts are hidden until you unblock them.',
          ),
        ),
      );
    }
    final List<PostItem>? posts = _posts == null
        ? null
        : sortPostsForView(_posts!, sort: _sort);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              uiText(context, zh: 'TA 的帖子', en: 'Posts'),
              style: ZxType.title.copyWith(color: t.text),
            ),
            if (posts != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '${posts.length}',
                style: ZxType.caption.copyWith(color: t.text3),
              ),
            ],
            const Spacer(),
            SegmentedButton<PostSort>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: <ButtonSegment<PostSort>>[
                ButtonSegment<PostSort>(
                  value: PostSort.latest,
                  label: Text(uiText(context, zh: '最新', en: 'Latest')),
                ),
                ButtonSegment<PostSort>(
                  value: PostSort.hot,
                  label: Text(uiText(context, zh: '最热', en: 'Top')),
                ),
              ],
              selected: <PostSort>{_sort},
              onSelectionChanged: (Set<PostSort> v) =>
                  setState(() => _sort = v.first),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          uiText(
            context,
            zh: '只列出 TA 以实名发布的公开帖子',
            en: 'Only their public posts under their own name',
          ),
          style: ZxType.caption.copyWith(color: t.text3),
        ),
        const SizedBox(height: 12),
        if (_postsError != null && posts == null)
          ZxInlineMessage(
            message: _postsError!,
            tone: ZxMessageTone.danger,
            actionLabel: uiText(context, zh: '重试', en: 'Retry'),
            onAction: _loadPosts,
          )
        else if (posts == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ZxStatePanel(
              icon: Icons.article_outlined,
              title: uiText(context, zh: '还没有公开帖子', en: 'No public posts yet'),
            ),
          )
        else
          for (final PostItem post in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: post, onTap: () => _openPost(post)),
            ),
      ],
    );
  }

  Widget _buildAbout(PublicUserProfile profile) {
    final ZxTokens t = ZxTokens.of(context);
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: t.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: ZxType.body.copyWith(color: t.text2)),
          ),
        ],
      ),
    );
    final String school = <String>[
      profile.college.trim(),
      profile.major.trim(),
    ].where((String s) => s.isNotEmpty).join(' · ');
    return ZxCard(
      key: const Key('public-profile-about'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            uiText(context, zh: '关于 TA', en: 'About'),
            style: ZxType.title.copyWith(color: t.text),
          ),
          const SizedBox(height: 8),
          if (school.isNotEmpty) line(Icons.school_outlined, school),
          if (profile.userLevelLabel.trim().isNotEmpty)
            line(
              Icons.workspace_premium_outlined,
              profile.userLevelLabelFor(Localizations.localeOf(context)),
            ),
          line(
            profile.canDirectMessage
                ? Icons.chat_bubble_outline_rounded
                : Icons.speaker_notes_off_outlined,
            profile.canDirectMessage
                ? uiText(context, zh: '可以私信', en: 'Open to messages')
                : uiText(context, zh: '未开放私信', en: 'Not taking messages'),
          ),
        ],
      ),
    );
  }

  void _feedback(String message) {
    if (!mounted) {
      return;
    }
    zxShowToast(context, message);
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$value ',
            style: ZxType.label.copyWith(color: t.text),
          ),
          TextSpan(
            text: label,
            style: ZxType.caption.copyWith(color: t.text3),
          ),
        ],
      ),
    );
  }
}
