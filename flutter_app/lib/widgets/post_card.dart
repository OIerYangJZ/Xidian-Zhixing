import 'package:flutter/material.dart';

import '../core/l10n/ui_text.dart';
import '../core/state/app_theme_store.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../models/post_item.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.onFavorite,
  });

  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    if (AppColorThemes.usesDiscussionLayout(AppThemeStore.instance.themeKey)) {
      return _buildDiscussionCard(context);
    }
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.56);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Avatar(post: post),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            post.authorAlias.isEmpty
                                ? uiText(
                                    context,
                                    zh: '匿名用户',
                                    en: 'Anonymous user',
                                  )
                                : post.authorAlias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _relativeTime(context, post.createdAt),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PostMeta(post: post),
                    if (post.title.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        post.title.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.55,
                          fontSize: 18,
                        ),
                      ),
                    ],
                    if (post.content.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        post.content.trim(),
                        maxLines: post.imageUrls.isEmpty ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.88,
                          ),
                          height: 1.75,
                        ),
                      ),
                    ],
                    if (post.imageUrls.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _ImageStrip(urls: post.imageUrls),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        _Action(
                          icon: post.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          value: post.likeCount,
                          active: post.isLiked,
                          onTap: onLike,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Action(
                          icon: Icons.mode_comment_outlined,
                          value: post.commentCount,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Action(
                          icon: post.isFavorited
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          value: post.favoriteCount,
                          active: post.isFavorited,
                          onTap: onFavorite,
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
    );
  }

  Widget _buildDiscussionCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colors.primarySubtle.withValues(alpha: 0.34),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DiscussionAvatar(post: post),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            post.authorAlias.isEmpty
                                ? uiText(context, zh: '匿名同学', en: 'Anonymous')
                                : post.authorAlias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _relativeTime(context, post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.mutedInk,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: colors.mutedInk,
                        ),
                      ],
                    ),
                    if (post.title.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        post.title.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.42,
                          color: colors.ink,
                        ),
                      ),
                    ],
                    if (post.content.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        post.content.trim(),
                        maxLines: post.imageUrls.isEmpty ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.ink,
                          height: 1.65,
                        ),
                      ),
                    ],
                    if (post.imageUrls.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _ImageStrip(urls: post.imageUrls),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        _DiscussionAction(
                          icon: post.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          value: post.likeCount,
                          active: post.isLiked,
                          onTap: onLike,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _DiscussionAction(
                          icon: Icons.mode_comment_outlined,
                          value: post.commentCount,
                          onTap: onTap,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _DiscussionAction(
                          icon: post.isFavorited
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          value: post.favoriteCount,
                          active: post.isFavorited,
                          onTap: onFavorite,
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
    );
  }

  String _relativeTime(BuildContext context, DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return uiText(context, zh: '刚刚', en: 'Just now');
    }
    if (diff.inMinutes < 60) {
      return uiText(
        context,
        zh: '${diff.inMinutes} 分钟前',
        en: '${diff.inMinutes}m ago',
      );
    }
    if (diff.inHours < 24) {
      return uiText(
        context,
        zh: '${diff.inHours} 小时前',
        en: '${diff.inHours}h ago',
      );
    }
    if (diff.inDays < 30) {
      return uiText(
        context,
        zh: '${diff.inDays} 天前',
        en: '${diff.inDays}d ago',
      );
    }
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class _DiscussionAvatar extends StatelessWidget {
  const _DiscussionAvatar({required this.post});

  final PostItem post;

  @override
  Widget build(BuildContext context) {
    final String label = post.authorAlias.trim().isEmpty
        ? '匿'
        : post.authorAlias.trim().characters.first;
    if (!post.isAnonymous && post.authorAvatarUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          post.authorAvatarUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _DiscussionFallbackAvatar(label: label),
        ),
      );
    }
    return _DiscussionFallbackAvatar(label: post.isAnonymous ? '匿' : label);
  }
}

class _DiscussionFallbackAvatar extends StatelessWidget {
  const _DiscussionFallbackAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: colors.primary),
      ),
    );
  }
}

class _DiscussionAction extends StatelessWidget {
  const _DiscussionAction({
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color color = active ? colors.primary : colors.mutedInk;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostMeta extends StatelessWidget {
  const _PostMeta({required this.post});

  final PostItem post;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> tags = post.tags
        .where((String tag) => tag.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        _MetaPill(
          label: post.channel.trim().isEmpty
              ? uiText(context, zh: '未分类', en: 'Uncategorized')
              : post.channel.trim(),
          color: theme.colorScheme.primary,
        ),
        if (post.isPinned)
          _MetaPill(
            label: uiText(context, zh: '置顶', en: 'Pinned'),
            color: theme.colorScheme.secondary,
          ),
        if (post.status != PostStatus.ongoing)
          _MetaPill(
            label: post.status.label,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        for (final String tag in tags)
          _MetaPill(
            label: '#${tag.trim()}',
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.post});

  final PostItem post;

  @override
  Widget build(BuildContext context) {
    final String label = post.authorAlias.trim().isEmpty
        ? '匿'
        : post.authorAlias.trim().characters.first;
    if (!post.isAnonymous && post.authorAvatarUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Image.network(
          post.authorAvatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackAvatar(label: label),
        ),
      );
    }
    return _FallbackAvatar(label: post.isAnonymous ? '匿' : label);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final int count = urls.length.clamp(1, 3);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = count > 1 ? 6 : 0;
        final double itemWidth = count == 1
            ? constraints.maxWidth.clamp(180, 360)
            : (constraints.maxWidth - gap * (count - 1)) / count;
        return Row(
          children: <Widget>[
            for (int index = 0; index < count; index++) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  urls[index],
                  width: itemWidth,
                  height: count == 1 ? 210 : itemWidth,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: itemWidth,
                    height: count == 1 ? 210 : itemWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.broken_image_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          uiText(
                            context,
                            zh: '图片加载失败',
                            en: 'Image failed to load',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != count - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
