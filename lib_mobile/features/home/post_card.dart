import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import '../widgets/avatar_widget.dart';

/// Twitter 风格帖子卡片
/// 无边距、无圆角、无阴影、全宽紧贴屏幕
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;
  final bool showTopDivider;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.onFavorite,
    this.showTopDivider = true,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTopDivider)
          Container(height: 0.5, color: MobileTheme.divider),
        GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列：头像
                _buildAvatar(),
                const SizedBox(width: 10),
                // 右列：内容
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
        Container(height: 0.5, color: MobileTheme.divider),
      ],
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () {
        if (widget.post.isOwnPost) {
          context.push('/profile');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('暂不支持查看该用户主页'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: AvatarWidget(
        avatarUrl: null,
        nickname: widget.post.authorAlias,
        radius: 20,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头部行：昵称 · 时间 · 频道（彩色圆点前缀）
        _buildHeaderRow(),
        const SizedBox(height: 4),

        // 标题
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MobileTheme.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],

        // 内容（最多 3 行）
        Text(
          widget.post.content,
          style: const TextStyle(
            fontSize: 14,
            color: MobileTheme.textPrimary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // 图片网格
        if (widget.post.hasImage && widget.post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ImageGrid(imageUrls: widget.post.imageUrls),
        ],

        // 标签（无背景，纯彩色 # 前缀）
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTags(),
        ],

        const SizedBox(height: 8),

        // 底部互动栏
        _buildActionBar(),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // 昵称
        Text(
          widget.post.authorAlias,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MobileTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        // 彩色圆点 + 频道名
        _ChannelDot(channel: widget.post.channel),
        const Spacer(),
        // 时间
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
      spacing: 8,
      runSpacing: 4,
      children: widget.post.tags.take(3).map((tag) {
        return Text(
          '#$tag',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MobileTheme.primary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBar() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            count: _likeCount,
            isActive: _isLiked,
            activeColor: MobileTheme.accent,
            onTap: _busy ? null : _handleLike,
          ),
          const SizedBox(width: 24),
          _ActionButton(
            icon: Icons.star_border,
            activeIcon: Icons.star,
            count: _favoriteCount,
            isActive: _isFavorited,
            activeColor: MobileTheme.warning,
            onTap: _busy ? null : _handleFavorite,
          ),
          const SizedBox(width: 24),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            count: widget.post.commentCount,
            isActive: false,
            activeColor: MobileTheme.primary,
            onTap: widget.onTap,
          ),
          const Spacer(),
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
      ),
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

/// 频道彩色圆点 + 频道名文本
class _ChannelDot extends StatelessWidget {
  final String channel;

  const _ChannelDot({required this.channel});

  static const _channelColors = {
    '全部': MobileTheme.textSecondary,
    '学习': Color(0xFF5E8FD4),
    '二手': Color(0xFF5EAF7C),
    '找搭子': Color(0xFFE09C5E),
    '失物': Color(0xFFD45E8A),
    '吐槽': Color(0xFF9B6ED4),
    '租房': Color(0xFF5EC4AF),
    '问答': Color(0xFF5EAAD4),
  };

  @override
  Widget build(BuildContext context) {
    final color = _channelColors[channel] ?? MobileTheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          channel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        if (channel == '问答' && false) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: MobileTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.zero,
            ),
            child: const Text(
              '已解决',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: MobileTheme.success,
              ),
            ),
          ),
        ],
      ],
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
      child: SizedBox(
        height: 32,
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
                  fontWeight: FontWeight.w500,
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

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          for (int i = 0; i < displayUrls.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _buildImage(displayUrls[i]),
              ),
            ),
          ],
          if (remaining > 0) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.zero,
                  color: MobileTheme.textTertiary.withValues(alpha: 0.15),
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
            ),
          ],
        ],
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
          size: 24,
        ),
      ),
    );
  }
}
