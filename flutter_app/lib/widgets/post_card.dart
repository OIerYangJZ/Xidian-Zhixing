import 'package:flutter/material.dart';

import '../core/theme/app_typography.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../models/post_item.dart';
import 'post_content_body.dart';

/// A continuous social-feed item. It intentionally has no card chrome: the
/// reading rhythm comes from one consistent divider and generous spacing.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onOpenPost,
    this.onAuthorTap,
    this.onHashtagTap,
    this.onLike,
    this.onFavorite,
  });

  final PostItem post;

  /// Opens the post detail when the feed item itself is selected.
  final VoidCallback onTap;
  final VoidCallback? onOpenPost;

  /// Opens the author's public profile. It is intentionally bound to the
  /// avatar alone so the rest of the item keeps its post-detail behavior.
  final VoidCallback? onAuthorTap;
  final ValueChanged<String>? onHashtagTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final PostItem post = widget.post;
    final ThemeData theme = Theme.of(context);
    final EditorialColors colors = EditorialColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.emphasis,
        color: _hovered
            ? colors.primarySubtle.withValues(alpha: 0.34)
            : colors.surface.withValues(alpha: 0),
        child: Material(
          color: colors.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: widget.onTap,
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
                  _Avatar(post: post, onTap: widget.onAuthorTap),
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
                                    ? '匿名同学'
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
                              _relativeTime(post.createdAt),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: colors.faintInk,
                            ),
                          ],
                        ),
                        if (post.title.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            post.title.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.postContentStyle(
                              theme.textTheme.titleMedium,
                            ).copyWith(height: 1.42, color: colors.ink),
                          ),
                        ],
                        if (post.content.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          HashtagText(
                            text: post.content.trim(),
                            maxLines: post.imageUrls.isEmpty ? 4 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.postContentStyle(
                              theme.textTheme.bodyMedium,
                            ).copyWith(color: colors.ink, height: 1.65),
                            onHashtagTap: widget.onHashtagTap,
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
                              onTap: widget.onLike,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            _Action(
                              icon: Icons.mode_comment_outlined,
                              value: post.commentCount,
                              onTap: widget.onOpenPost,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            _Action(
                              icon: post.isFavorited
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              value: post.favoriteCount,
                              active: post.isFavorited,
                              onTap: widget.onFavorite,
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
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.post, this.onTap});
  final PostItem post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String label = post.authorAlias.trim().isEmpty
        ? '匿'
        : post.authorAlias.trim().characters.first;
    final Widget avatar;
    if (!post.isAnonymous && post.authorAvatarUrl.trim().isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          post.authorAvatarUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackAvatar(label: label),
        ),
      );
    } else {
      avatar = _FallbackAvatar(label: post.isAnonymous ? '匿' : label);
    }
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.label});
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

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final int count = urls.length.clamp(1, 3);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.xs;
        final double itemWidth = count == 1
            ? constraints.maxWidth.clamp(180, 420)
            : (constraints.maxWidth - gap * (count - 1)) / count;
        return Row(
          children: <Widget>[
            for (int index = 0; index < count; index++) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.large),
                child: Image.network(
                  urls[index],
                  width: itemWidth,
                  height: count == 1 ? 240 : itemWidth,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: itemWidth,
                    height: count == 1 ? 240 : itemWidth,
                    color: colors.primarySubtle,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              if (index != count - 1) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _Action extends StatefulWidget {
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
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color color = widget.active ? colors.primary : colors.mutedInk;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onHighlightChanged: (bool pressed) => setState(() => _pressed = pressed),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.emphasis,
        scale: _pressed ? 0.9 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.xxs),
              AnimatedDefaultTextStyle(
                duration: AppMotion.resolve(context, AppMotion.fast),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium!.copyWith(color: color),
                child: Text('${widget.value}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
