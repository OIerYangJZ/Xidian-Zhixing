import 'dart:convert';

import 'package:flutter/material.dart';

class ImageGallery extends StatelessWidget {
  const ImageGallery({
    super.key,
    required this.images,
    this.onRemove,
  });

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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (BuildContext context, int index) {
            return _ImageTile(
              imageUrl: images[index],
              onTap: () => _showImageViewer(context, index),
            );
          },
        ),
      ],
    );
  }

  void _showImageViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _ImageViewerPage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final VoidCallback onTap;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_hasError) {
      content = Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, color: Colors.black38, size: 32),
            SizedBox(height: 4),
            Text(
              '加载失败',
              style: TextStyle(color: Colors.black45, fontSize: 10),
            ),
          ],
        ),
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          _buildImage(),
        ],
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  Widget _buildImage() {
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
            frameBuilder: (BuildContext context, Widget child, int? frame,
                bool? wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded == true) {
                return child;
              }
              if (frame != null) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
              return const SizedBox.shrink();
            },
            errorBuilder: (BuildContext context, Object error,
                StackTrace? stackTrace) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
              return const SizedBox.shrink();
            },
          );
        } catch (_) {
          _hasError = true;
          _isLoading = false;
        }
      }
    }

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return child;
        }
        return const SizedBox.shrink();
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
  });

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: PageView.builder(
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
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          SizedBox(height: 16),
          Text(
            '图片加载失败',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      );
    }

    if (widget.imageUrl.startsWith('data:')) {
      final int commaIndex = widget.imageUrl.indexOf(',');
      if (commaIndex != -1) {
        final String base64Data = widget.imageUrl.substring(commaIndex + 1);
        try {
          return Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.contain,
            frameBuilder: (BuildContext context, Widget child, int? frame,
                bool? wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded == true || frame != null) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
              return _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : child;
            },
            errorBuilder: (BuildContext context, Object error,
                StackTrace? stackTrace) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
              return const SizedBox.shrink();
            },
          );
        } catch (_) {
          _hasError = true;
        }
      }
    }

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return child;
        }
        return const CircularProgressIndicator(color: Colors.white);
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
