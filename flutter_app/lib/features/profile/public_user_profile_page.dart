import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../messages/chat_page.dart';

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
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
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
      _feedback(profile.isFollowing ? '已取消关注' : '关注成功');
    } catch (error) {
      _feedback('操作失败：$error');
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
      _feedback('无法发起私信：$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PublicUserProfile? profile = _profile;
    final String backgroundImageUrl = AppConfig.resolveUrl(
      profile?.backgroundImageUrl ?? '',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('个人主页')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? const AppStatePanel(
                  icon: Icons.person_search_outlined,
                  title: '正在加载个人主页',
                  message: '正在同步公开资料和互动状态。',
                )
              : ListView(
                  padding: AppLayout.pagePadding(context),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                height: 136,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  image: backgroundImageUrl.isEmpty
                                      ? null
                                      : DecorationImage(
                                          image: NetworkImage(
                                            backgroundImageUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: <Widget>[
                                  _Avatar(
                                    avatarUrl: profile.avatarUrl,
                                    nickname: profile.nickname,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          profile.nickname,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '等级：${profile.userLevelLabel}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (profile.bio.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 14),
                                Text(
                                  profile.bio.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.82),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              if (profile.gender.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      profile.gender == '男'
                                          ? Icons.male
                                          : Icons.female,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.58),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      profile.gender.trim(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.58),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  _StatChip(
                                    label: '帖子',
                                    value: '${profile.postCount}',
                                  ),
                                  _StatChip(
                                    label: '关注',
                                    value: '${profile.followingCount}',
                                  ),
                                  _StatChip(
                                    label: '粉丝',
                                    value: '${profile.followerCount}',
                                  ),
                                ],
                              ),
                              if (profile.canFollow ||
                                  profile.canDirectMessage) ...<Widget>[
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    if (profile.canFollow)
                                      FilledButton.icon(
                                        onPressed: _busy ? null : _toggleFollow,
                                        icon: Icon(
                                          profile.isFollowing
                                              ? Icons
                                                    .person_remove_alt_1_outlined
                                              : Icons.person_add_alt_1_outlined,
                                        ),
                                        label: Text(
                                          profile.isFollowing ? '取消关注' : '关注',
                                        ),
                                      ),
                                    if (profile.canDirectMessage)
                                      OutlinedButton.icon(
                                        onPressed: _busy ? null : _handleDm,
                                        icon: const Icon(Icons.forum_outlined),
                                        label: const Text('私信'),
                                      ),
                                  ],
                                ),
                                if (!profile.canDirectMessage)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      '对方当前未开放私信入口',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.58),
                                          ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (profile == null && _error == null)
                      const AppStatePanel(
                        icon: Icons.person_off_outlined,
                        title: '无法显示个人主页',
                        message: '该用户不存在，或主页当前不可访问。',
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _feedback(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.nickname});

  final String avatarUrl;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final String displayName = nickname.trim().isEmpty ? '用户' : nickname.trim();
    final String resolvedAvatarUrl = AppConfig.resolveUrl(avatarUrl.trim());
    final ImageProvider<Object>? imageProvider = resolvedAvatarUrl.isEmpty
        ? null
        : NetworkImage(resolvedAvatarUrl);
    final String initial = displayName.substring(0, 1);
    return CircleAvatar(
      radius: 30,
      backgroundImage: imageProvider,
      child: imageProvider == null ? Text(initial) : null,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
