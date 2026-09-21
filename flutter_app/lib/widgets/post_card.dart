import 'package:flutter/material.dart';

import '../core/l10n/ui_text.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';
import '../models/post_item.dart';

/// Threads-style timeline item used by the web reference pages.
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
    final bool desktop = AppBreakpoints.isDesktop(context);
    final double scale = desktop
        ? AppLayout.shellScale(MediaQuery.sizeOf(context).width)
        : 1;
    final double avatarSize = desktop ? 50 * scale : 42;
    final double horizontal = desktop ? 33 * scale : AppSpacing.md;
    final double top = desktop ? 22 * scale : AppSpacing.md;
    final double bottom = desktop ? 23 * scale : AppSpacing.md;
    final double gap = desktop ? 17 * scale : AppSpacing.sm;
    final double bodySize = desktop ? 22 * scale : 16;
    final double bodyHeight = desktop ? 29 * scale : 24;
    final double actionSize = desktop ? 28 * scale : 20;
    final double actionTextSize = desktop ? 18 * scale : 13;
    final EditorialColors colors = EditorialColors.of(context);
    final String author = post.authorAlias.trim().isEmpty
        ? uiText(context, zh: '匿名同学', en: 'Anonymous')
        : post.authorAliasFor(Localizations.localeOf(context));
    final String copy = <String>[post.title.trim(), post.content.trim()]
        .where((String value) => value.isNotEmpty)
        .join(
          post.title.trim().isNotEmpty && post.content.trim().isNotEmpty
              ? '\n'
              : '',
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colors.primarySubtle.withValues(alpha: .28),
        child: Container(
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DiscussionAvatar(post: post, size: avatarSize),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: bodySize,
                              height: 26 / 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          _compactTime(context, post.createdAt),
                          style: TextStyle(
                            color: colors.mutedInk,
                            fontSize: desktop ? 18 * scale : 13,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        const Spacer(),
                        Text(
                          '···',
                          style: TextStyle(
                            color: colors.mutedInk,
                            fontFamily: 'Arial',
                            fontSize: desktop ? 26 * scale : 22,
                            height: .7,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    if (copy.isNotEmpty) ...<Widget>[
                      SizedBox(height: 4 * scale),
                      Text(
                        copy,
                        maxLines: post.imageUrls.isEmpty ? 12 : 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: bodySize,
                          height: bodyHeight / bodySize,
                          letterSpacing: desktop ? .02 * scale : 0,
                        ),
                      ),
                    ],
                    if (post.imageUrls.isNotEmpty) ...<Widget>[
                      SizedBox(height: 12 * scale),
                      _ImageStrip(
                        urls: post.imageUrls,
                        scale: scale,
                        desktop: desktop,
                      ),
                    ],
                    SizedBox(height: 20 * scale),
                    Row(
                      children: <Widget>[
                        _DiscussionAction(
                          icon: post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          value: post.likeCount,
                          active: post.isLiked,
                          onTap: onLike,
                          iconSize: actionSize,
                          textSize: actionTextSize,
                        ),
                        SizedBox(width: desktop ? 31 * scale : 24),
                        _DiscussionAction(
                          icon: Icons.chat_bubble_outline,
                          value: post.commentCount,
                          onTap: onTap,
                          iconSize: actionSize,
                          textSize: actionTextSize,
                        ),
                        SizedBox(width: desktop ? 31 * scale : 24),
                        _DiscussionAction(
                          icon: Icons.repeat,
                          value: post.favoriteCount,
                          iconSize: actionSize,
                          textSize: actionTextSize,
                        ),
                        SizedBox(width: desktop ? 31 * scale : 24),
                        _DiscussionAction(
                          icon: Icons.send_outlined,
                          value: post.viewCount,
                          iconSize: actionSize,
                          textSize: actionTextSize,
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

  String _compactTime(BuildContext context, DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return uiText(context, zh: '刚刚', en: 'now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year.toString().substring(2)}';
  }
}

class _DiscussionAvatar extends StatelessWidget {
  const _DiscussionAvatar({required this.post, required this.size});

  final PostItem post;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String anonymousInitial = uiText(context, zh: '匿', en: 'A');
    final String alias = post
        .authorAliasFor(Localizations.localeOf(context))
        .trim();
    final String label = alias.isEmpty
        ? anonymousInitial
        : alias.characters.first;
    final Widget avatar =
        post.isAnonymous || post.authorAvatarUrl.trim().isEmpty
        ? _DiscussionFallbackAvatar(
            label: post.isAnonymous ? anonymousInitial : label,
            size: size,
          )
        : ClipOval(
            child: Image.network(
              post.authorAvatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _DiscussionFallbackAvatar(label: label, size: size),
            ),
          );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          avatar,
          Positioned(
            right: -3 * size / 50,
            bottom: -3 * size / 50,
            child: Container(
              width: 25 * size / 50,
              height: 25 * size / 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2 * size / 50,
                ),
              ),
              child: Container(
                width: 20 * size / 50,
                height: 20 * size / 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '+',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontSize: 16 * size / 50,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussionFallbackAvatar extends StatelessWidget {
  const _DiscussionFallbackAvatar({required this.label, required this.size});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: EditorialColors.of(context).primarySubtle,
      shape: BoxShape.circle,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: size * .42,
        color: EditorialColors.of(context).primary,
      ),
    ),
  );
}

class _DiscussionAction extends StatelessWidget {
  const _DiscussionAction({
    required this.icon,
    required this.value,
    required this.iconSize,
    required this.textSize,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final int value;
  final double iconSize;
  final double textSize;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color color = active ? const Color(0xFFFF003B) : colors.mutedInk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: iconSize),
            const SizedBox(width: 6),
            Text(
              _formatCount(value),
              style: TextStyle(color: color, fontSize: textSize, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000)
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return '$value';
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({
    required this.urls,
    required this.scale,
    required this.desktop,
  });
  final List<String> urls;
  final double scale;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final int count = urls.length.clamp(1, 3);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = (desktop ? 8 : 6) * scale;
        final double maxSingle = desktop ? 477 * scale : 360;
        final double stripWidth = desktop
            ? constraints.maxWidth + 34 * scale
            : constraints.maxWidth;
        final double itemWidth = count == 1
            ? maxSingle.clamp(0, constraints.maxWidth)
            : (stripWidth - gap * (count - 1)) / count;
        final double height = count == 1 ? 597 * scale : 389 * scale;
        return SizedBox(
          width: count == 1 ? itemWidth : stripWidth,
          height: height,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < count; i++) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12 * scale),
                  child: Image.network(
                    urls[i],
                    width: itemWidth,
                    height: height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: itemWidth,
                      height: height,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                if (i != count - 1) SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }
}
