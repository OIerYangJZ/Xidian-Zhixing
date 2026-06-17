import 'package:flutter/material.dart';

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
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.56);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Avatar(post: post),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          post.authorAlias.isEmpty ? '匿名用户' : post.authorAlias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(post.createdAt),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  if (post.title.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      post.title.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: SharedColors.textPrimary,
                      ),
                    ),
                  ],
                  if (post.content.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      post.content.trim(),
                      maxLines: post.imageUrls.isEmpty ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                  if (post.imageUrls.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    _ImageStrip(urls: post.imageUrls),
                  ],
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 24),
                      _Action(
                        icon: Icons.mode_comment_outlined,
                        value: post.commentCount,
                      ),
                      const SizedBox(width: 24),
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
    );
  }

  String _relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} 天前';
    }
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.post});

  final PostItem post;

  @override
  Widget build(BuildContext context) {
    final String label =
        post.authorAlias.trim().isEmpty ? '匿' : post.authorAlias.trim().characters.first;
    if (!post.isAnonymous && post.authorAvatarUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
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
                          '图片加载失败',
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
