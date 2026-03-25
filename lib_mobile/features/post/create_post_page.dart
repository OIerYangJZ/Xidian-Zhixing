import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';

/// 发帖页
/// 支持标题、正文、频道/标签选择、图片上传
class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _selectedChannel = '全部';
  List<String> _selectedTags = [];
  bool _allowComment = true;
  bool _allowDm = false;
  bool _isAnonymous = false;
  String _anonymousAlias = '';
  PostStatus _postStatus = PostStatus.ongoing;

  final _anonymousAliasController = TextEditingController();

  final List<XFile> _selectedImages = [];
  final List<String> _uploadedImageIds = [];
  bool _isUploading = false;
  bool _isPublishing = false;

  List<String> _channels = [];
  bool _isLoadingChannels = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _anonymousAliasController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final postRepo = ref.read(postRepositoryProvider);
      final channels = await postRepo.fetchChannels();
      if (mounted) {
        setState(() {
          _channels = channels.isNotEmpty
              ? channels
              : ['全部', '学习', '二手', '找搭子', '失物招领', '吐槽'];
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _channels = ['全部', '学习', '二手', '找搭子', '失物招领', '吐槽'];
          _isLoadingChannels = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final maxImages = 9 - _selectedImages.length;
        final imagesToAdd = images.take(maxImages).toList();

        setState(() {
          _selectedImages.addAll(imagesToAdd);
        });

        // 上传图片
        _uploadImages(imagesToAdd);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadImages(List<XFile> images) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64Data = base64Encode(bytes);
        final fileName = image.name;
        final contentType = _getContentType(image.path);

        try {
          final uploadedImage = await postRepo.uploadImage(
            fileName: fileName,
            contentType: contentType,
            dataBase64: base64Data,
          );
          _uploadedImageIds.add(uploadedImage.id);
        } catch (e) {
          // 单张图片上传失败，继续其他图片
          debugPrint('图片上传失败: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _getContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _generateAnonymousAlias() {
    final adjectives = ['神秘', '路过的', '隔壁的', '匿名的', '安静的', '好奇的', '悠闲的', '低调的'];
    final nouns = ['同学', '路人', '学长', '学弟', '学妹', '小伙伴', '小伙伴', '小伙伴'];
    final adj = adjectives[(DateTime.now().millisecondsSinceEpoch ~/ 13) % adjectives.length];
    final noun = nouns[(DateTime.now().millisecondsSinceEpoch ~/ 17) % nouns.length];
    return '$adj$noun';
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _uploadedImageIds.length) {
        _uploadedImageIds.removeAt(index);
      }
    });
  }

  void _showChannelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ChannelPickerSheet(
        channels: _channels,
        selectedChannel: _selectedChannel,
        onSelect: (channel) {
          setState(() {
            _selectedChannel = channel;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TagPickerSheet(
        selectedTags: _selectedTags,
        onSelect: (tags) {
          setState(() {
            _selectedTags = tags;
          });
        },
      ),
    );
  }

  Future<void> _handlePublish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入帖子内容')),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      final input = CreatePostInput(
        title: _titleController.text.trim(),
        content: content,
        channel: _selectedChannel == '全部' ? '全部' : _selectedChannel,
        tags: _selectedTags,
        allowComment: _allowComment,
        allowDm: _allowDm,
        status: _postStatus,
        hasImage: _selectedImages.isNotEmpty,
        imageUploadIds: _uploadedImageIds,
        useAnonymousAlias: _isAnonymous,
        anonymousAlias: _isAnonymous ? _anonymousAliasController.text : null,
      );

      await postRepo.createPost(input);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布成功！')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmDiscard(),
        ),
        title: const Text('发帖'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('发布'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入
            Container(
              color: MobileTheme.surface,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                maxLength: 50,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '标题（选填，不超过50字）',
                  hintStyle: TextStyle(
                    color: MobileTheme.textTertiary,
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),

            const Divider(height: 1),

            // 正文输入
            Container(
              color: MobileTheme.surface,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 6,
                style: const TextStyle(
                  fontSize: 16,
                  color: MobileTheme.textPrimary,
                  height: 1.6,
                ),
                decoration: const InputDecoration(
                  hintText: '分享你的想法...',
                  hintStyle: TextStyle(
                    color: MobileTheme.textTertiary,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            // 图片预览
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                color: MobileTheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildImagePreview(),
              ),
            ],

            // 上传进度
            if (_isUploading)
              Container(
                color: MobileTheme.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '图片上传中...',
                      style: TextStyle(
                        fontSize: 13,
                        color: MobileTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // 设置区域
            Container(
              color: MobileTheme.surface,
              child: Column(
                children: [
                  // 频道选择
                  _SettingsTile(
                    icon: Icons.grid_view,
                    label: '频道',
                    value: _selectedChannel,
                    onTap: _showChannelPicker,
                  ),

                  const Divider(height: 1, indent: 56),

                  // 标签选择
                  _SettingsTile(
                    icon: Icons.tag,
                    label: '标签',
                    value: _selectedTags.isEmpty
                        ? '选择标签'
                        : _selectedTags.join(', '),
                    onTap: _showTagPicker,
                  ),

                  const Divider(height: 1, indent: 56),

                  // 状态选择
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: '状态',
                    value: _postStatus.label,
                    onTap: _showStatusPicker,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 开关设置
            Container(
              color: MobileTheme.surface,
              child: Column(
                children: [
                  _SwitchTile(
                    icon: Icons.chat_bubble_outline,
                    label: '允许评论',
                    value: _allowComment,
                    onChanged: (value) {
                      setState(() {
                        _allowComment = value;
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _SwitchTile(
                    icon: Icons.mail_outline,
                    label: '允许私信',
                    value: _allowDm,
                    onChanged: (value) {
                      setState(() {
                        _allowDm = value;
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _SwitchTile(
                    icon: Icons.visibility_off_outlined,
                    label: '匿名发布',
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                        if (value) {
                          if (_anonymousAlias.isEmpty) {
                            _anonymousAlias = _generateAnonymousAlias();
                          }
                          _anonymousAliasController.text = _anonymousAlias;
                        }
                      });
                    },
                  ),
                  if (_isAnonymous) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                      child: TextField(
                        controller: _anonymousAliasController,
                        style: const TextStyle(fontSize: 14, color: MobileTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: '自定义匿名别名（选填）',
                          hintStyle: const TextStyle(color: MobileTheme.textTertiary, fontSize: 14),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: MobileTheme.textSecondary),
                          filled: true,
                          fillColor: MobileTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 添加图片按钮（始终可见）
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: MobileTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 22, color: MobileTheme.primary),
                    const SizedBox(width: 14),
                    Text(
                      '添加图片',
                      style: const TextStyle(fontSize: 15, color: MobileTheme.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      '最多9张',
                      style: const TextStyle(fontSize: 13, color: MobileTheme.textTertiary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20, color: MobileTheme.textTertiary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            // 添加按钮
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: MobileTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MobileTheme.divider,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: MobileTheme.textSecondary,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '添加图片',
                      style: TextStyle(
                        fontSize: 12,
                        color: MobileTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final image = _selectedImages[index];
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: MobileTheme.background,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MobileTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择状态',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                ),
              ),
            ),
            ...PostStatus.values.map((status) => ListTile(
                  leading: Icon(
                    status == PostStatus.resolved
                        ? Icons.check_circle
                        : status == PostStatus.closed
                            ? Icons.lock
                            : Icons.help_outline,
                    color: status == _postStatus
                        ? MobileTheme.primary
                        : MobileTheme.textSecondary,
                  ),
                  title: Text(status.label),
                  trailing: status == _postStatus
                      ? const Icon(Icons.check, color: MobileTheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _postStatus = status;
                    });
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDiscard() {
    if (_titleController.text.isEmpty &&
        _contentController.text.isEmpty &&
        _selectedImages.isEmpty) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃编辑？'),
        content: const Text('确定要放弃当前编辑内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }
}

/// 设置项（带图标和值）
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: MobileTheme.textSecondary),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: MobileTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: MobileTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: MobileTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 开关项
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: MobileTheme.textSecondary),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: MobileTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MobileTheme.primary,
          ),
        ],
      ),
    );
  }
}

/// 频道选择器
class _ChannelPickerSheet extends StatelessWidget {
  final List<String> channels;
  final String selectedChannel;
  final Function(String) onSelect;

  const _ChannelPickerSheet({
    required this.channels,
    required this.selectedChannel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择频道',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MobileTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final isSelected = channel == selectedChannel;
                return ListTile(
                  title: Text(
                    channel,
                    style: TextStyle(
                      color: isSelected
                          ? MobileTheme.primary
                          : MobileTheme.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: MobileTheme.primary)
                      : null,
                  onTap: () => onSelect(channel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 标签选择器
class _TagPickerSheet extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onSelect;

  const _TagPickerSheet({
    required this.selectedTags,
    required this.onSelect,
  });

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late List<String> _tempSelected;
  final _customTagController = TextEditingController();

  final _allTags = [
    '求助',
    '学习',
    '二手',
    '组队',
    '经验',
    '吐槽',
    '交友',
    '活动',
    '租房',
    '实习',
    '考研',
    '保研',
    '出国',
    '竞赛',
    '社团',
  ];

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tempSelected.contains(tag)) {
        _tempSelected.remove(tag);
      } else {
        if (_tempSelected.length < 5) {
          _tempSelected.add(tag);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多选择5个标签')),
          );
        }
      }
    });
  }

  void _addCustomTags() {
    final input = _customTagController.text.trim();
    if (input.isEmpty) return;

    final newTags = input
        .split(RegExp(r'[,，\s\n]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_tempSelected.contains(t))
        .toList();

    if (newTags.isEmpty) return;

    final remaining = 5 - _tempSelected.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多选择5个标签')),
      );
      return;
    }

    setState(() {
      _tempSelected.addAll(newTags.take(remaining));
      _customTagController.clear();
    });

    if (newTags.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只添加了$remaining个标签，达到上限5个')),
      );
    }
  }

  List<Widget> _buildSelectedTagsPreview() {
    if (_tempSelected.isEmpty) return [];
    return [
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _tempSelected.map((tag) {
          return GestureDetector(
            onTap: () => _toggleTag(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: MobileTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MobileTheme.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MobileTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 14, color: MobileTheme.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择标签（最多5个）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MobileTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onSelect(_tempSelected);
                  Navigator.pop(context);
                },
                child: const Text('完成'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTags.map((tag) {
              final isSelected = _tempSelected.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.primary.withValues(alpha: 0.15)
                        : MobileTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? MobileTheme.primary
                          : MobileTheme.divider,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? MobileTheme.primary
                          : MobileTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 自定义标签输入
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  decoration: InputDecoration(
                    hintText: '输入自定义标签，多个用逗号分隔',
                    hintStyle: const TextStyle(fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: MobileTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: MobileTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: MobileTheme.primary),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) => _addCustomTags(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _addCustomTags,
                child: const Text('添加'),
              ),
            ],
          ),
          ..._buildSelectedTagsPreview(),
        ],
      ),
    );
  }
}
