import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/mobile_theme.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/post_item.dart';

/// 帖子卡片组件
/// 支持：标题/摘要/频道标签/时间戳、图片网格（最多3张）、点赞/收藏/评论数、点击跳转详情
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.onFavorite,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  /// 乐观更新状态
  bool _isLiked = false;
  bool _isFavorited = false;
  int _likeCount = 0;
  int _favoriteCount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _isFavorited = widget.post.isFavorited;
    _likeCount = widget.post.likeCount;
    _favoriteCount = widget.post.favoriteCount;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _isFavorited = widget.post.isFavorited;
      _likeCount = widget.post.likeCount;
      _favoriteCount = widget.post.favoriteCount;
    }
  }

  Future<void> _handleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      widget.onLike?.call();
    } catch (_) {
      // 回滚
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleFavorite() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _isFavorited = !_isFavorited;
      _favoriteCount += _isFavorited ? 1 : -1;
    });
    try {
      widget.onFavorite?.call();
    } catch (_) {
      // 回滚
      if (mounted) {
        setState(() {
          _isFavorited = !_isFavorited;
          _favoriteCount += _isFavorited ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MobileTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：频道标签 + 状态 + 时间
            _buildHeader(),
            const SizedBox(height: 10),

            // 标题
            if (widget.post.title.isNotEmpty) ...[
              Text(
                widget.post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],

            // 内容摘要
            Text(
              widget.post.content,
              style: const TextStyle(
                fontSize: 14,
                color: MobileTheme.textSecondary,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 图片网格
            if (widget.post.hasImage && widget.post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ImageGrid(imageUrls: widget.post.imageUrls),
            ],

            // 标签
            if (widget.post.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTags(),
            ],

            const SizedBox(height: 12),

            // 底部互动栏
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _ChannelTag(channel: widget.post.channel),
            if (widget.post.status == PostStatus.resolved) ...[
              const SizedBox(width: 6),
              const _StatusTag(label: '已解决', color: MobileTheme.success),
            ],
            if (widget.post.isPinned) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.push_pin,
                size: 14,
                color: MobileTheme.accent,
              ),
            ],
          ],
        ),
        Text(
          _formatTime(widget.post.createdAt),
          style: const TextStyle(
            fontSize: 12,
            color: MobileTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.post.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: MobileTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$tag',
            style: const TextStyle(
              fontSize: 12,
              color: MobileTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.favorite_border,
          activeIcon: Icons.favorite,
          count: _likeCount,
          isActive: _isLiked,
          activeColor: MobileTheme.accent,
          onTap: _busy ? null : _handleLike,
        ),
        const SizedBox(width: 16),
        _ActionButton(
          icon: Icons.star_border,
          activeIcon: Icons.star,
          count: _favoriteCount,
          isActive: _isFavorited,
          activeColor: MobileTheme.warning,
          onTap: _busy ? null : _handleFavorite,
        ),
        const SizedBox(width: 16),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          count: widget.post.commentCount,
          isActive: false,
          activeColor: MobileTheme.primary,
          onTap: widget.onTap,
        ),
        const Spacer(),
        // 分享按钮
        GestureDetector(
          onTap: () => _handleShare(context),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.share_outlined,
              size: 18,
              color: MobileTheme.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  void _handleShare(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}

class _ChannelTag extends StatelessWidget {
  final String channel;

  const _ChannelTag({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MobileTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        channel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: MobileTheme.primary,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? activeColor : MobileTheme.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 18,
              color: effectiveColor,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: effectiveColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> imageUrls;

  const _ImageGrid({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final displayUrls = imageUrls.take(3).toList();
    final remaining = imageUrls.length - 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            for (int i = 0; i < displayUrls.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(displayUrls[i]),
                ),
              ),
            ],
            if (remaining > 0) ...[
              const SizedBox(width: 4),
              Container(
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: MobileTheme.textTertiary.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MobileTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    final fullUrl =
        imageUrl.startsWith('http') ? imageUrl : AppConfig.resolveUrl(imageUrl);
    return CachedNetworkImage(
      imageUrl: fullUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: MobileTheme.background,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MobileTheme.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: MobileTheme.background,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: MobileTheme.textTertiary,
        ),
      ),
    );
  }
}
