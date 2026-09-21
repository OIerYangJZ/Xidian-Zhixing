import 'package:flutter/material.dart';
import '../common/feature_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PublicUserProfile? profile = _profile;
    final String backgroundImageUrl = AppConfig.resolveUrl(
      profile?.backgroundImageUrl ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '个人主页', en: 'Profile')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? AppStatePanel(
                  icon: Icons.person_search_outlined,
                  title: uiText(context, zh: '正在加载个人主页', en: 'Loading profile'),
                  message: uiText(
                    context,
                    zh: '正在同步公开资料和互动状态。',
                    en: 'Syncing the public profile and interaction status.',
                  ),
                )
              : ListView(
                  padding: AppLayout.pagePadding(context),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppInlineMessage(
                          title: uiText(
                            context,
                            zh: '个人主页加载失败',
                            en: 'Could not load the profile',
                          ),
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: _loadProfile,
                            child: Text(uiText(context, zh: '重试', en: 'Retry')),
                          ),
                        ),
                      ),
                    if (profile != null) ...<Widget>[
                      FeatureSection(
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (backgroundImageUrl.isNotEmpty)
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
                                          profile.nicknameFor(locale),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          uiText(
                                            context,
                                            zh: '等级：${profile.userLevelLabelFor(locale)}',
                                            en: 'Level: ${profile.userLevelLabelFor(locale)}',
                                          ),
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
                                      profile.genderFor(locale).trim(),
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
                                    label: uiText(
                                      context,
                                      zh: '帖子',
                                      en: 'Posts',
                                    ),
                                    value: '${profile.postCount}',
                                  ),
                                  _StatChip(
                                    label: uiText(
                                      context,
                                      zh: '关注',
                                      en: 'Following',
                                    ),
                                    value: '${profile.followingCount}',
                                  ),
                                  _StatChip(
                                    label: uiText(
                                      context,
                                      zh: '粉丝',
                                      en: 'Followers',
                                    ),
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
                                          profile.isFollowing
                                              ? uiText(
                                                  context,
                                                  zh: '取消关注',
                                                  en: 'Unfollow',
                                                )
                                              : uiText(
                                                  context,
                                                  zh: '关注',
                                                  en: 'Follow',
                                                ),
                                        ),
                                      ),
                                    if (profile.canDirectMessage)
                                      OutlinedButton.icon(
                                        onPressed: _busy ? null : _handleDm,
                                        icon: const Icon(Icons.forum_outlined),
                                        label: Text(
                                          uiText(
                                            context,
                                            zh: '私信',
                                            en: 'Message',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!profile.canDirectMessage)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      uiText(
                                        context,
                                        zh: '对方当前未开放私信入口',
                                        en: 'This user has not enabled direct messages.',
                                      ),
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
                      AppStatePanel(
                        icon: Icons.person_off_outlined,
                        title: uiText(
                          context,
                          zh: '无法显示个人主页',
                          en: 'Profile unavailable',
                        ),
                        message: uiText(
                          context,
                          zh: '该用户不存在，或主页当前不可访问。',
                          en: 'This user does not exist, or the profile is currently unavailable.',
                        ),
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
    final String displayName = nickname.trim().isEmpty
        ? uiText(context, zh: '用户', en: 'User')
        : localizedAlias(Localizations.localeOf(context), nickname.trim());
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
