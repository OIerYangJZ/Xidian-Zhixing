import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/shared_colors.dart';

class ImageGallery extends StatelessWidget {
  const ImageGallery({super.key, required this.images, this.onRemove});

  final List<String> images;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          '图片（${images.length}）',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columnCount = constraints.maxWidth < 420
                ? 2
                : constraints.maxWidth >= 700
                ? 4
                : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
              ),
              itemCount: images.length,
              itemBuilder: (BuildContext context, int index) {
                return _ImageTile(
                  imageUrl: images[index],
                  onTap: () => _showImageViewer(context, index),
                  onRemove: onRemove == null ? null : () => onRemove!(index),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showImageViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: EditorialColors.of(context).darkPanel,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _ImageViewerPage(images: images, initialIndex: initialIndex),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.imageUrl,
    required this.onTap,
    this.onRemove,
  });

  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Semantics(
      button: true,
      label: '打开图片预览',
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: InkWell(onTap: widget.onTap, child: _buildImage(context)),
          ),
          if (widget.onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filled(
                tooltip: '移除图片',
                onPressed: widget.onRemove,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  backgroundColor: colors.darkPanel.withValues(alpha: 0.76),
                  foregroundColor: colors.onDarkPanel,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Widget errorPlaceholder = ColoredBox(
      color: colors.primarySubtle,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, color: colors.mutedInk, size: 32),
            const SizedBox(height: 4),
            Text(
              '加载失败',
              style: TextStyle(color: colors.mutedInk, fontSize: 10),
            ),
          ],
        ),
      ),
    );
    final Widget loadingPlaceholder = ColoredBox(
      color: colors.primarySubtle,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    if (widget.imageUrl.startsWith('data:')) {
      final int commaIndex = widget.imageUrl.indexOf(',');
      if (commaIndex != -1) {
        final String base64Data = widget.imageUrl.substring(commaIndex + 1);
        try {
          return Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return errorPlaceholder;
                },
          );
        } catch (_) {
          return errorPlaceholder;
        }
      }
    }

    final String resolvedUrl = AppConfig.resolveUrl(widget.imageUrl);
    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            return loadingProgress == null ? child : loadingPlaceholder;
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return errorPlaceholder;
          },
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Scaffold(
      backgroundColor: colors.darkPanel,
      body: Stack(
        children: [
          // 图片页面
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: _ViewerImage(imageUrl: widget.images[index]),
                ),
              );
            },
          ),
          // 顶部关闭按钮和指示器（与移动端一致的样式）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      tooltip: '关闭图片预览',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.darkPanel.withValues(
                          alpha: 0.76,
                        ),
                        foregroundColor: colors.onDarkPanel,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.darkPanel.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: TextStyle(
                          color: colors.onDarkPanel,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
          if (widget.images.length > 1 && _currentIndex > 0)
            Positioned(
              left: AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  tooltip: '上一张',
                  onPressed: () => _pageController.previousPage(
                    duration: AppMotion.resolve(context, AppMotion.page),
                    curve: AppMotion.settle,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.darkPanel.withValues(alpha: 0.76),
                    foregroundColor: colors.onDarkPanel,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
            ),
          if (widget.images.length > 1 &&
              _currentIndex < widget.images.length - 1)
            Positioned(
              right: AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  tooltip: '下一张',
                  onPressed: () => _pageController.nextPage(
                    duration: AppMotion.resolve(context, AppMotion.page),
                    curve: AppMotion.settle,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.darkPanel.withValues(alpha: 0.76),
                    foregroundColor: colors.onDarkPanel,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerImage extends StatefulWidget {
  const _ViewerImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Widget errorPlaceholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.broken_image_outlined, color: colors.railMuted, size: 64),
        const SizedBox(height: 16),
        Text('图片加载失败', style: TextStyle(color: colors.railMuted)),
      ],
    );
    final Widget loadingPlaceholder = CircularProgressIndicator(
      color: colors.onDarkPanel,
    );

    if (widget.imageUrl.startsWith('data:')) {
      final int commaIndex = widget.imageUrl.indexOf(',');
      if (commaIndex != -1) {
        final String base64Data = widget.imageUrl.substring(commaIndex + 1);
        try {
          return Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return errorPlaceholder;
                },
          );
        } catch (_) {
          return errorPlaceholder;
        }
      }
    }

    final String resolvedUrl = AppConfig.resolveUrl(widget.imageUrl);
    return Image.network(
      resolvedUrl,
      fit: BoxFit.contain,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            return loadingProgress == null ? child : loadingPlaceholder;
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return errorPlaceholder;
          },
    );
  }
}
