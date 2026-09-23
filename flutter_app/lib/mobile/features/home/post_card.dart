import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/utils/post_share.dart';
import '../../core/utils/time_utils.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import '../post/image_gallery.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/seal_widgets.dart';

/// Instagram 风格帖子卡片
/// 无边距、无圆角、无阴影、全宽紧贴屏幕
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final bool showTopDivider;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.showTopDivider = true,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _busy = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _showDots = false;
  Timer? _dotsHideTimer;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _currentImageIndex = 0;
      _showDots = false;
      _dotsHideTimer?.cancel();
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _dotsHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenImage(int initialIndex) {
    ImageGallery.show(
      context,
      imageUrls: widget.post.imageUrls,
      initialIndex: initialIndex,
    );
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

  @override
  Widget build(BuildContext context) {
    final MobileColors colors = MobileColors.of(context);
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border(
            top: widget.showTopDivider
                ? BorderSide(color: colors.divider, width: 0.5)
                : BorderSide.none,
            bottom: BorderSide(color: colors.divider, width: 0.5),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final bool isAnon = widget.post.isAnonymous;
    final bool hasUserId = widget.post.authorUserId.isNotEmpty;
    return GestureDetector(
      onTap: () {
        // 匿名帖一律不能通过头像查看主页
        if (!isAnon && hasUserId) {
          if (widget.post.isOwnPost) {
            context.push('/profile');
          } else {
            context.push('/user/${widget.post.authorUserId}');
          }
        }
      },
      child: isAnon
          ? SealAvatar(text: widget.post.authorAlias, size: 40)
          : AvatarWidget(
              avatarUrl: widget.post.authorAvatarUrl,
              nickname: widget.post.authorAlias,
              radius: 20,
            ),
    );
  }

  Widget _buildContent() {
    if (widget.post.hasImage && widget.post.imageUrls.isNotEmpty) {
      return _buildImagePostContent();
    }

    return _buildTextPostContent();
  }

  /// 图文帖：标题 + PageView 图片（无正文）
  Widget _buildImagePostContent() {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        const SizedBox(height: 4),

        // 标题 - 18sp Bold
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        // 图片 PageView - 固定高度 280dp
        _buildImagePageView(),

        // 标签
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTags(),
        ],

        const SizedBox(height: 8),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildImagePageView() {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.post.imageUrls.length,
              onPageChanged: (index) {
                _dotsHideTimer?.cancel();
                setState(() {
                  _currentImageIndex = index;
                  _showDots = true;
                });
                _dotsHideTimer = Timer(const Duration(seconds: 1), () {
                  if (mounted) setState(() => _showDots = false);
                });
              },
              itemBuilder: (context, index) {
                final fullUrl = _resolveImageUrl(widget.post.imageUrls[index]);
                return GestureDetector(
                  onTap: () => _openFullScreenImage(index),
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: colors.divider,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.divider,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.textTertiary,
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
            // 圆点指示器 - 仅滑动时显示，停止1秒后自动隐藏
            if (widget.post.imageUrls.length > 1 && _showDots)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.post.imageUrls.length, (i) {
                    final isActive = _currentImageIndex == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 8 : 6,
                      height: isActive ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 纯文帖：标题 + 正文（最多4行）
  Widget _buildTextPostContent() {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        const SizedBox(height: 4),

        // 标题 - 18sp Bold
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],

        // 正文 - 最多 4 行
        Text(
          widget.post.content,
          style: TextStyle(
            fontSize: 14,
            color: colors.textPrimary,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),

        // 标签
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTags(),
        ],

        const SizedBox(height: 8),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildHeaderRow() {
    final colors = MobileColors.of(context);
    return Row(
      children: [
        Text(
          widget.post.authorAlias,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        SealBadge(text: widget.post.channel, type: SealBadgeType.light),
        if (widget.post.isPinned) ...[
          const SizedBox(width: 6),
          const SealBadge(text: '置顶', type: SealBadgeType.solid),
        ],
        const Spacer(),
        Text(
          _formatTime(widget.post.createdAt),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.post.tags.take(3).map((tag) {
        return SealBadge(text: '#$tag', type: SealBadgeType.light);
      }).toList(),
    );
  }

  Widget _buildActionBar() {
    final colors = MobileColors.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            count: _likeCount,
            isActive: _isLiked,
            activeColor: colors.primary,
            onTap: _busy ? null : _handleLike,
          ),
          const SizedBox(width: 24),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            count: widget.post.commentCount,
            isActive: false,
            activeColor: colors.primary,
            onTap: widget.onTap,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _handleShare(context),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.share_outlined,
                size: 22,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    await copyPostShareLink(widget.post.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制帖子链接'), duration: Duration(seconds: 1)),
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }

  String _resolveImageUrl(String imageUrl) {
    return imageUrl.startsWith('http')
        ? imageUrl
        : AppConfig.resolveUrl(imageUrl);
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
    final colors = MobileColors.of(context);
    final inactiveColor = colors.textPrimary;
    final effectiveColor = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 22, color: effectiveColor),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
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
