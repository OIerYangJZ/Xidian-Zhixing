import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/ui_text.dart';
import '../core/navigation/share_links.dart';
import '../design_system/design_system.dart';
import '../features/post/report_dialog.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';

/// A post in a list (handoff: Components · POST CARD, discussion layout).
///
/// Every marker the post carries is shown: 置顶, 匿名, 分区, 进行中 /
/// 已解决 / 已结束, 仅自己可见, and on one's own posts 待审核 / 未通过审核.
/// The 「⋯」 menu offers 复制链接, 复制内容, 举报, and 删除 on one's own posts
/// when [onDeleted] is given.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.onFavorite,
    this.onAuthorTap,
    this.onDeleted,
    this.highlight,
  });

  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;

  /// Opens the author's profile. Never called for anonymous posts.
  final VoidCallback? onAuthorTap;

  /// Removes the post from the caller's list after 删除. Without it the
  /// menu does not offer 删除, since the post would stay on screen.
  final VoidCallback? onDeleted;

  /// Search keyword to mark in the title and body.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String author = post.authorAlias.isEmpty
        ? uiText(context, zh: '匿名用户', en: 'Anonymous user')
        : post.authorAliasFor(locale);
    final String body = post.content.trim();

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              post.isAnonymous
                  ? ZxAvatar.anonymous(name: author)
                  : ZxAvatar(
                      name: author,
                      imageUrl: post.authorAvatarUrl,
                      onTap: onAuthorTap,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ZxType.label.copyWith(color: t.text),
                                ),
                              ),
                              Text(
                                ' · ${relativeTime(context, post.createdAt)}',
                                style: ZxType.caption.copyWith(color: t.text3),
                              ),
                            ],
                          ),
                        ),
                        SizedBox.square(
                          dimension: 32,
                          child: IconButton(
                            key: Key('post-card-more-${post.id}'),
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            tooltip: uiText(context, zh: '更多', en: 'More'),
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: t.text3,
                            ),
                            onPressed: () => _openMenu(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    PostMarkers(post: post),
                    if (post.title.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: highlightSpans(
                            post.title.trim(),
                            highlight,
                            TextStyle(color: t.primary),
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZxType.title.copyWith(color: t.text),
                      ),
                    ],
                    if (body.isNotEmpty || post.tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            ...highlightSpans(
                              body,
                              highlight,
                              TextStyle(
                                color: t.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            for (final String tag in post.tags)
                              TextSpan(
                                text: '${body.isEmpty ? '' : ' '}#$tag',
                                style: TextStyle(
                                  color: t.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        maxLines: post.imageUrls.isEmpty ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: ZxType.body.copyWith(color: t.text2),
                      ),
                    ],
                    if (post.imageUrls.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      _Images(urls: post.imageUrls),
                    ],
                    const SizedBox(height: 8),
                    _Actions(
                      post: post,
                      onLike: onLike,
                      onComment: onTap,
                      onFavorite: onFavorite,
                      onShare: () => _copyLink(context),
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

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: ShareLink.post(post.id).url));
    if (context.mounted) {
      zxShowToast(
        context,
        uiText(context, zh: '已复制帖子链接', en: 'Post link copied'),
      );
    }
  }

  Future<void> _openMenu(BuildContext context) async {
    final bool canCopyText = !post.isMarkdown;
    final bool canDelete = post.isOwnPost && onDeleted != null;
    final String? action = await zxShowActionSheet<String>(
      context,
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      actions: <ZxSheetAction<String>>[
        ZxSheetAction<String>(
          value: 'link',
          label: uiText(context, zh: '复制链接', en: 'Copy link'),
          icon: Icons.link_rounded,
        ),
        if (canCopyText)
          ZxSheetAction<String>(
            value: 'text',
            label: uiText(context, zh: '复制内容', en: 'Copy text'),
            icon: Icons.copy_rounded,
          ),
        if (!post.isOwnPost)
          ZxSheetAction<String>(
            value: 'report',
            label: uiText(context, zh: '举报', en: 'Report'),
            icon: Icons.flag_outlined,
          ),
        if (canDelete)
          ZxSheetAction<String>(
            value: 'delete',
            label: uiText(context, zh: '删除', en: 'Delete'),
            icon: Icons.delete_outline_rounded,
            danger: true,
          ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'link':
        await _copyLink(context);
      case 'text':
        await Clipboard.setData(
          ClipboardData(
            text:
                '${post.sectionName.isEmpty ? '' : '[${post.sectionName}] '}'
                '${post.title}\n${post.content}',
          ),
        );
        if (context.mounted) {
          zxShowToast(
            context,
            uiText(context, zh: '已复制帖子内容', en: 'Post content copied'),
          );
        }
      case 'report':
        await _report(context);
      case 'delete':
        await _delete(context);
    }
  }

  Future<void> _report(BuildContext context) async {
    final ReportChoice? choice = await showReportDialog(context);
    if (choice == null || !context.mounted) return;
    try {
      await AppRepositories.posts.report(
        targetType: 'post',
        targetId: post.id,
        reason: choice.reason,
        description: choice.description,
      );
      if (context.mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '已提交举报', en: 'Report submitted'),
        );
      }
    } catch (error) {
      if (context.mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '举报失败：$error', en: 'Report failed: $error'),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '删除这条帖子？', en: 'Delete this post?'),
      message: uiText(context, zh: '删除后无法恢复。', en: 'This cannot be undone.'),
      confirmLabel: uiText(context, zh: '删除', en: 'Delete'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await AppRepositories.posts.deleteMyPost(post.id);
      onDeleted?.call();
      if (context.mounted) {
        zxShowToast(context, uiText(context, zh: '帖子已删除', en: 'Post deleted'));
      }
    } catch (error) {
      if (context.mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '删除失败：$error', en: 'Delete failed: $error'),
        );
      }
    }
  }
}

/// [text] as spans with each case-insensitive occurrence of [query] styled
/// with [match]. A leading # on the query is ignored, so #组队 marks 组队.
List<TextSpan> highlightSpans(String text, String? query, TextStyle match) {
  final String needle = (query ?? '').trim().replaceFirst(RegExp(r'^#'), '');
  if (needle.isEmpty || text.isEmpty) {
    return <TextSpan>[TextSpan(text: text)];
  }
  final String haystack = text.toLowerCase();
  final String lowered = needle.toLowerCase();
  final List<TextSpan> spans = <TextSpan>[];
  int start = 0;
  while (true) {
    final int at = haystack.indexOf(lowered, start);
    if (at < 0) {
      spans.add(TextSpan(text: text.substring(start)));
      return spans;
    }
    if (at > start) {
      spans.add(TextSpan(text: text.substring(start, at)));
    }
    spans.add(
      TextSpan(text: text.substring(at, at + needle.length), style: match),
    );
    start = at + needle.length;
  }
}

/// 刚刚 / N 分钟前 / N 小时前 / N 天前, then MM-DD.
String relativeTime(BuildContext context, DateTime time) {
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
    return uiText(context, zh: '${diff.inDays} 天前', en: '${diff.inDays}d ago');
  }
  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

/// A post's badge row, shared by cards and post detail. Order follows the
/// handoff: 置顶, 匿名, 分区, status, then
/// visibility and review state.
class PostMarkers extends StatelessWidget {
  const PostMarkers({super.key, required this.post});

  final PostItem post;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String section = post.sectionName.trim();
    final List<Widget> badges = <Widget>[
      if (post.isPinned)
        ZxBadge.pinned(uiText(context, zh: '置顶', en: 'Pinned')),
      if (post.isAnonymous)
        ZxBadge.anonymous(uiText(context, zh: '匿名', en: 'Anonymous')),
      // Posts from before sections have none.
      if (section.isNotEmpty)
        ZxBadge.channel(section, color: t.channelFor(section)),
      switch (post.status) {
        PostStatus.ongoing => ZxBadge.inProgress(post.status.labelFor(locale)),
        PostStatus.resolved => ZxBadge.resolved(post.status.labelFor(locale)),
        PostStatus.closed => ZxBadge.closed(post.status.labelFor(locale)),
      },
      if (post.isPrivate)
        ZxBadge.private(uiText(context, zh: '仅自己可见', en: 'Only me')),
      if (post.reviewStatus == 'pending')
        ZxBadge.pendingReview(uiText(context, zh: '待审核', en: 'In review')),
      if (post.reviewStatus == 'rejected')
        ZxBadge.rejected(uiText(context, zh: '未通过审核', en: 'Rejected')),
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }
}

/// Up to three thumbnails; more show as +N on the last.
class _Images extends StatelessWidget {
  const _Images({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final int shown = urls.length.clamp(1, 3);
    final int more = urls.length - shown;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 6;
        final double width = shown == 1
            ? constraints.maxWidth.clamp(180, 420)
            : (constraints.maxWidth - gap * (shown - 1)) / shown;
        final double height = shown == 1 ? width * 0.6 : width;
        Widget placeholder() => Container(
          width: width,
          height: height,
          color: t.bgSunk,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: t.text3),
        );
        // Decode at the tile's pixel size: uploads are full photos, and
        // decoding each at full resolution for a 130 px tile is what stalls
        // a list of cards. BoxFit.cover crops, so the short side must fill.
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final bool wideImage = width >= height;
        final int decodeSide = ((wideImage ? width : height) * dpr).ceil();
        return Row(
          children: <Widget>[
            for (int i = 0; i < shown; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: gap),
              ClipRRect(
                borderRadius: ZxRadius.buttonAll,
                child: Stack(
                  children: <Widget>[
                    Image.network(
                      urls[i],
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      cacheWidth: wideImage ? decodeSide : null,
                      cacheHeight: wideImage ? null : decodeSide,
                      errorBuilder: (_, _, _) => placeholder(),
                    ),
                    if (more > 0 && i == shown - 1)
                      Positioned.fill(
                        child: ColoredBox(
                          color: t.scrim,
                          child: Center(
                            child: Text(
                              '+$more',
                              style: ZxType.titleLarge.copyWith(
                                color: t.onScrim,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.onShare,
  });

  final PostItem post;
  final VoidCallback? onLike;
  final VoidCallback onComment;
  final VoidCallback? onFavorite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Row(
      children: <Widget>[
        PostActionPill(
          icon: post.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: post.likeCount,
          active: post.isLiked,
          activeColor: t.primary,
          activeFill: t.primarySoft,
          label: uiText(context, zh: '点赞', en: 'Like'),
          onTap: onLike,
        ),
        PostActionPill(
          icon: Icons.chat_bubble_outline_rounded,
          count: post.commentCount,
          label: uiText(context, zh: '评论', en: 'Comments'),
          onTap: onComment,
        ),
        PostActionPill(
          icon: post.isFavorited
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          count: post.favoriteCount,
          active: post.isFavorited,
          activeColor: t.accentInk,
          activeFill: t.accentSoft,
          label: uiText(context, zh: '收藏', en: 'Save'),
          onTap: onFavorite,
        ),
        const Spacer(),
        IconButton(
          tooltip: uiText(context, zh: '复制链接', en: 'Copy link'),
          iconSize: 18,
          icon: Icon(Icons.ios_share_rounded, color: t.text3),
          onPressed: onShare,
        ),
      ],
    );
  }
}

/// Like / comment / save pill with a count; tinted while [active].
class PostActionPill extends StatelessWidget {
  const PostActionPill({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.activeFill,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;
  final Color? activeFill;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color color = active ? activeColor! : t.text3;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: '$label $count',
        child: Material(
          color: active ? activeFill : Colors.transparent,
          borderRadius: ZxRadius.pillAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: ZxRadius.pillAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: ZxType.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
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
}
