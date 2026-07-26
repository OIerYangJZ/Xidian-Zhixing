import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/post_card.dart';
import '../messages/chat_page.dart';
import '../search/search_page.dart';

class PublicUserProfilePage extends ConsumerStatefulWidget {
  const PublicUserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicUserProfilePage> createState() =>
      _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends ConsumerState<PublicUserProfilePage> {
  PublicUserProfile? _profile;
  List<PostItem> _posts = const <PostItem>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  _ProfileTab _selectedTab = _ProfileTab.threads;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
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
      final List<PostItem> posts = await AppRepositories.posts.fetchUserPosts(
        profile.id,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '加载失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null || _busy || !profile.canFollow || profile.id.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      if (profile.isFollowing) {
        await repository.unfollowUser(profile.id);
      } else {
        await repository.followUser(profile.id);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isFollowing: !profile.isFollowing,
          followerCount: profile.isFollowing
              ? (profile.followerCount > 0 ? profile.followerCount - 1 : 0)
              : profile.followerCount + 1,
        );
      });
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleDm() async {
    final PublicUserProfile? profile = _profile;
    if (profile == null || profile.id.isEmpty || _busy) return;
    setState(() => _busy = true);
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
      _feedback('无法发起私信：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPost(PostItem post) async {
    await openPostDetailPage(context, post: post);
  }

  void _openHashtag(String hashtag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialKeyword: hashtag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final PublicUserProfile? profile = _profile;
    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.readingMaxWidth,
            ),
            child: _loading
                ? const AppStatePanel(
                    icon: Icons.person_search_outlined,
                    title: '正在加载个人主页',
                    message: '正在读取公开资料。',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                    children: <Widget>[
                      _ProfileTopBar(onBack: () => Navigator.of(context).pop()),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: AppInlineMessage(
                            title: '个人主页加载失败',
                            message: _error!,
                            tone: AppMessageTone.error,
                            action: TextButton(
                              onPressed: _loadProfile,
                              child: const Text('重试'),
                            ),
                          ),
                        ),
                      if (profile != null) ...<Widget>[
                        _ProfileHeader(
                          profile: profile,
                          isOwnProfile:
                              AuthStore.instance.currentUser?.userId ==
                              profile.id,
                          busy: _busy,
                          onFollow: _toggleFollow,
                          onMessage: _handleDm,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ProfileTabs(
                          selected: _selectedTab,
                          onChanged: (_ProfileTab value) =>
                              setState(() => _selectedTab = value),
                        ),
                        Divider(height: 1, color: colors.line),
                        _ProfileTimeline(
                          tab: _selectedTab,
                          posts: _posts,
                          onPostOpen: _openPost,
                          onHashtagOpen: _openHashtag,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ProfileTab { threads, replies, media, reposts }

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => AppPageTopActions(
    leading: IconButton(
      onPressed: onBack,
      tooltip: '返回',
      icon: const Icon(Icons.arrow_back_rounded),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    required this.busy,
    required this.onFollow,
    required this.onMessage,
  });

  final PublicUserProfile profile;
  final bool isOwnProfile;
  final bool busy;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String backgroundUrl = AppConfig.resolveUrl(
      profile.backgroundImageUrl,
    );
    final String avatarUrl = AppConfig.resolveUrl(profile.avatarUrl);
    final String initial = profile.nickname.trim().isEmpty
        ? '匿'
        : profile.nickname.trim().characters.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 118,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    child: backgroundUrl.isEmpty
                        ? ColoredBox(color: colors.surfaceHover)
                        : Image.network(backgroundUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: -34,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: colors.surface,
                    backgroundImage: avatarUrl.isEmpty
                        ? null
                        : NetworkImage(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(
                            initial,
                            style: Theme.of(context).textTheme.titleLarge,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            profile.nickname,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '@${profile.nickname}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
          ),
          if (profile.bio.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              profile.bio.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '${profile.followerCount} 粉丝   ${profile.followingCount} 关注   ${profile.postCount} 帖子',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedInk),
          ),
          if (!isOwnProfile &&
              (profile.canFollow || profile.canDirectMessage)) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                if (profile.canFollow)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onFollow,
                      child: Text(profile.isFollowing ? '已关注' : '关注'),
                    ),
                  ),
                if (profile.canFollow && profile.canDirectMessage)
                  const SizedBox(width: AppSpacing.sm),
                if (profile.canDirectMessage)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onMessage,
                      child: const Text('私信'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selected, required this.onChanged});

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onChanged;

  static const List<(_ProfileTab, String)> _tabs = <(_ProfileTab, String)>[
    (_ProfileTab.threads, '帖子'),
    (_ProfileTab.replies, '回复'),
    (_ProfileTab.media, '媒体'),
    (_ProfileTab.reposts, '转发'),
  ];

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Row(
      children: _tabs
          .map(((_ProfileTab, String) item) {
            final bool active = selected == item.$1;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: AppMotion.resolve(context, AppMotion.standard),
                  curve: AppMotion.emphasis,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? colors.ink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    item.$2,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active ? colors.ink : colors.mutedInk,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ProfileTimeline extends StatelessWidget {
  const _ProfileTimeline({
    required this.tab,
    required this.posts,
    required this.onPostOpen,
    required this.onHashtagOpen,
  });

  final _ProfileTab tab;
  final List<PostItem> posts;
  final ValueChanged<PostItem> onPostOpen;
  final ValueChanged<String> onHashtagOpen;

  @override
  Widget build(BuildContext context) {
    final List<PostItem> visiblePosts = switch (tab) {
      _ProfileTab.threads => posts,
      _ProfileTab.media =>
        posts.where((PostItem post) => post.hasImage).toList(),
      _ProfileTab.replies || _ProfileTab.reposts => const <PostItem>[],
    };
    if (visiblePosts.isEmpty) {
      final String message = switch (tab) {
        _ProfileTab.threads => '还没有发布内容',
        _ProfileTab.replies => '还没有公开回复',
        _ProfileTab.media => '还没有媒体内容',
        _ProfileTab.reposts => '还没有转发内容',
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    final EditorialColors colors = EditorialColors.of(context);
    return Column(
      children: <Widget>[
        for (int index = 0; index < visiblePosts.length; index++) ...<Widget>[
          PostCard(
            post: visiblePosts[index],
            onTap: () => onPostOpen(visiblePosts[index]),
            onOpenPost: () => onPostOpen(visiblePosts[index]),
            onHashtagTap: onHashtagOpen,
          ),
          if (index != visiblePosts.length - 1)
            Divider(height: 1, color: colors.line),
        ],
      ],
    );
  }
}
