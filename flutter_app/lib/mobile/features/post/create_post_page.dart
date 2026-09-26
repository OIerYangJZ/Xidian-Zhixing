import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/code_point_limit.dart';
import '../../../design_system/design_system.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/square_icon_button.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/section_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

/// 发帖 (handoff P1–P3). The title, body and images sit in one card, the
/// settings in another. 发布 checks everything at once (P2): a banner counts
/// what is missing and jumps to it, each field says what it needs. While
/// publishing (P3) the form dims and locks, and the top bar shows the image
/// uploads and their progress. Images upload on publish, not on pick, so a
/// removed image never lingers as an upload.
class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  static const int _titleMax = PostLimits.title;
  static const int _contentMax = PostLimits.plainContent;
  static const int _imageMax = 9;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _sectionKey = GlobalKey();
  final GlobalKey _tagsKey = GlobalKey();

  SectionItem? _section;
  List<String> _tags = <String>[];
  PostStatus _status = PostStatus.ongoing;
  bool _privateOnly = false;
  bool _isAnonymous = false;
  int? _pinMinutes;
  bool _isLevelOneUser =
      AuthStore.instance.currentUser?.isLevelOneUser ?? false;

  final List<XFile> _images = <XFile>[];
  List<SectionItem> _sections = <SectionItem>[];
  List<ClubItem> _clubs = <ClubItem>[];
  String? _sectionsLoadError;

  /// Set after the first 发布, so errors only show once asked for.
  bool _showErrors = false;
  bool _publishing = false;
  String? _progressText;

  /// Null while submitting without images: the bar runs indeterminate.
  double? _progress;

  @override
  void initState() {
    super.initState();
    _loadSections();
    _loadUserLevel();
    _titleController.addListener(_refresh);
    _contentController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _loadSections() async {
    setState(() => _sectionsLoadError = null);
    try {
      final PostRepository repo = ref.read(postRepositoryProvider);
      final (List<SectionItem> sections, List<ClubItem> clubs) = await (
        repo.fetchSections(),
        repo.fetchClubs(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _sections = postableSections(sections, clubs);
        // 综合 unless the user picks another.
        _section ??= _sections
            .where((SectionItem s) => s.isGeneral)
            .firstOrNull;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sectionsLoadError = '分区加载失败：$error');
    }
  }

  Future<void> _loadUserLevel() async {
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      setState(() => _isLevelOneUser = profile.isLevelOneUser);
    } catch (_) {
      // Keep the cached level.
    }
  }

  // ---- validation ----

  String? get _titleError {
    final String title = _titleController.text.trim();
    if (title.isEmpty) return '请填写标题';
    if (title.runes.length > _titleMax) return '标题最多 $_titleMax 字';
    return null;
  }

  String? get _contentError {
    final String content = _contentController.text.trim();
    if (content.isEmpty) return '请填写正文';
    if (content.runes.length > _contentMax) {
      return '正文最多 $_contentMax 字';
    }
    return null;
  }

  String? get _sectionError => _section == null ? '请选择分区' : null;

  /// The server merges the #topics in the title and body into the tags.
  String? get _tagError => PostLimits.tagProblem(
    _tags,
    _titleController.text.trim(),
    _contentController.text.trim(),
  );

  /// Missing or invalid fields, in page order.
  List<GlobalKey> get _missing => <GlobalKey>[
    if (_titleError != null) _titleKey,
    if (_contentError != null) _contentKey,
    if (_sectionError != null) _sectionKey,
    if (_tagError != null) _tagsKey,
  ];

  void _scrollTo(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  // ---- actions ----

  Future<void> _pickImages() async {
    final int room = _imageMax - _images.length;
    if (room <= 0) {
      zxShowToast(context, '最多 $_imageMax 张图片');
      return;
    }
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted || picked.isEmpty) return;
      if (picked.length > room) {
        zxShowToast(context, '最多 $_imageMax 张，已保留前 $room 张');
      }
      setState(() => _images.addAll(picked.take(room)));
    } catch (error) {
      if (mounted) zxShowToast(context, '选择图片失败：$error');
    }
  }

  String _contentType(String path) {
    switch (path.split('.').last.toLowerCase()) {
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

  /// Fills the alias from the server's word list (随机). Errors only matter
  /// when the user asked explicitly; on the automatic fill the field just
  /// stays empty and the server falls back to 匿名同学.
  Future<void> _fillRandomAlias({bool explicit = false}) async {
    try {
      final String alias = await ref
          .read(postRepositoryProvider)
          .fetchRandomAnonymousAlias();
      if (!mounted || !_isAnonymous) return;
      setState(() => _aliasController.text = alias);
    } catch (error) {
      if (!mounted || !explicit) return;
      zxShowToast(context, '随机昵称获取失败：$error');
    }
  }

  void _setAnonymous(bool value) {
    setState(() {
      _isAnonymous = value;
      if (!value) _aliasController.clear();
    });
    if (value && _aliasController.text.isEmpty) _fillRandomAlias();
  }

  Future<void> _publish() async {
    if (_publishing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final List<GlobalKey> missing = _missing;
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      _scrollTo(missing.first);
      return;
    }
    final PostRepository repo = ref.read(postRepositoryProvider);
    final int total = _images.length;
    setState(() {
      _publishing = true;
      _progress = total == 0 ? null : 0;
      _progressText = total == 0 ? '正在发布' : '正在上传图片 0/$total';
    });
    try {
      final List<String> uploadIds = <String>[];
      for (int i = 0; i < total; i++) {
        final XFile image = _images[i];
        final uploaded = await repo.uploadImage(
          fileName: image.name,
          contentType: _contentType(image.path),
          dataBase64: base64Encode(await image.readAsBytes()),
        );
        uploadIds.add(uploaded.id);
        if (!mounted) return;
        setState(() {
          _progress = (i + 1) / total;
          _progressText = i + 1 < total ? '正在上传图片 ${i + 1}/$total' : '正在发布';
        });
      }
      await repo.createPost(
        CreatePostInput(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          section: _section!,
          publisherClub: publisherClubFor(_section!, _clubs),
          tags: _tags,
          allowComment: true,
          allowDm: !_isAnonymous,
          privateOnly: _privateOnly,
          status: _status,
          hasImage: uploadIds.isNotEmpty,
          imageUploadIds: uploadIds,
          useAnonymousAlias: _isAnonymous,
          anonymousAlias: _isAnonymous ? _aliasController.text.trim() : null,
          pinDurationMinutes: _pinMinutes,
        ),
      );
      if (!mounted) return;
      zxShowToast(context, _isAnonymous ? '已悄悄放进树洞' : '发布成功');
      context.pop();
    } on ApiException catch (error) {
      if (mounted) zxShowToast(context, '发布失败：${error.message}');
    } catch (error) {
      if (mounted) zxShowToast(context, '发布失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
          _progressText = null;
        });
      }
    }
  }

  Future<void> _confirmDiscard() async {
    if (_publishing) return;
    if (_titleController.text.isEmpty &&
        _contentController.text.isEmpty &&
        _images.isEmpty) {
      context.pop();
      return;
    }
    final bool discard = await zxConfirm(
      context,
      title: '放弃编辑？',
      message: '当前填写的内容不会保存。',
      confirmLabel: '放弃',
      cancelLabel: '继续编辑',
      danger: true,
    );
    if (discard && mounted) context.pop();
  }

  Future<void> _editTags() async {
    final List<String>? tags = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagSheet(selected: _tags),
    );
    if (tags != null && mounted) setState(() => _tags = tags);
  }

  // ---- layout ----

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final List<GlobalKey> missing = _showErrors ? _missing : const [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.surface,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Opacity(
              opacity: _publishing ? 0.4 : 1,
              child: SquareIconButton(
                icon: Icons.close_rounded,
                tooltip: '关闭',
                onTap: _confirmDiscard,
              ),
            ),
          ),
          leadingWidth: 60,
          titleSpacing: 4,
          title: const Text('发布'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ZxButton(
                key: const Key('mobile-create-publish'),
                label: _publishing ? '发布中' : '发布',
                small: true,
                loading: _publishing,
                onPressed: _publish,
              ),
            ),
          ],
          bottom: _publishing
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(34),
                  child: _ProgressLine(
                    text: _progressText ?? '',
                    value: _progress,
                  ),
                )
              : null,
        ),
        body: IgnorePointer(
          ignoring: _publishing,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _publishing ? 0.55 : 1,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                if (missing.isNotEmpty) ...[
                  ZxInlineMessage(
                    key: const Key('mobile-create-errors'),
                    tone: ZxMessageTone.danger,
                    message: '还有 ${missing.length} 项需要填写',
                    actionLabel: '点击定位',
                    onAction: () => _scrollTo(missing.first),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildEditorCard(t),
                const SizedBox(height: 12),
                _buildSettingsCard(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorCard(ZxTokens t) {
    final String? titleError = _showErrors ? _titleError : null;
    final String? contentError = _showErrors ? _contentError : null;
    final int titleLength = _titleController.text.trim().runes.length;
    final int contentLength = _contentController.text.trim().runes.length;
    return ZxCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: _titleKey,
            padding: const EdgeInsets.fromLTRB(14, 2, 12, 2),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: ZxRadius.buttonAll,
              border: Border.all(
                color: titleError != null ? t.danger : t.line,
                width: titleError != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('mobile-create-title'),
                    controller: _titleController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    style: ZxType.title.copyWith(color: t.text),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      hintText: '标题（必填）',
                      hintStyle: ZxType.title.copyWith(
                        color: t.text3,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Text(
                  '$titleLength/$_titleMax',
                  style: ZxType.micro.copyWith(
                    color: titleLength > _titleMax ? t.danger : t.text3,
                  ),
                ),
              ],
            ),
          ),
          if (titleError != null) _FieldError(titleError),
          const SizedBox(height: 4),
          Divider(height: 16, color: t.line),
          TextField(
            key: const Key('mobile-create-content'),
            controller: _contentController,
            minLines: 6,
            maxLines: null,
            style: ZxType.body.copyWith(color: t.text, height: 1.7),
            decoration: InputDecoration(
              filled: false,
              hintText: '今天想悄悄说些什么？',
              hintStyle: ZxType.body.copyWith(color: t.text3),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
          Row(
            key: _contentKey,
            children: [
              if (contentError != null)
                Expanded(child: _FieldError(contentError))
              else
                const Spacer(),
              Text(
                '$contentLength/$_contentMax',
                style: ZxType.micro.copyWith(
                  color: contentLength > _contentMax ? t.danger : t.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildImages(t),
        ],
      ),
    );
  }

  Widget _buildImages(ZxTokens t) {
    const double side = 84;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < _images.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: ZxRadius.buttonAll,
                child: Image.file(
                  File(_images[i].path),
                  width: side,
                  height: side,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(width: side, height: side, color: t.bgSunk),
                ),
              ),
              if (i == 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.scrim,
                      borderRadius: ZxRadius.badgeAll,
                    ),
                    child: Text(
                      '封面',
                      style: ZxType.micro.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: t.scrim,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_images.length < _imageMax)
          Material(
            color: t.bgSunk,
            borderRadius: ZxRadius.buttonAll,
            child: InkWell(
              key: const Key('mobile-create-add-image'),
              borderRadius: ZxRadius.buttonAll,
              onTap: _pickImages,
              child: SizedBox(
                width: side,
                height: side,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: t.text3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_images.length}/$_imageMax',
                      style: ZxType.micro.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsCard(ZxTokens t) {
    final String? sectionError = _showErrors ? _sectionError : null;
    final String? tagError = _showErrors ? _tagError : null;
    Widget heading(String label, {bool required = false, Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(label, style: ZxType.label.copyWith(color: t.text)),
              if (required)
                Text(' *', style: ZxType.label.copyWith(color: t.primary)),
              const Spacer(),
              ?trailing,
            ],
          ),
        );
    Widget section(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: child,
    );
    Widget divider() => Divider(height: 1, color: t.line);

    return ZxCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            Column(
              key: _sectionKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('分区', required: true),
                if (_sectionsLoadError != null)
                  Row(
                    children: [
                      Expanded(child: _FieldError(_sectionsLoadError!)),
                      ZxButton(
                        label: '重试',
                        small: true,
                        variant: ZxButtonVariant.ghost,
                        onPressed: _loadSections,
                      ),
                    ],
                  )
                else
                  Container(
                    padding: sectionError != null
                        ? const EdgeInsets.all(8)
                        : EdgeInsets.zero,
                    decoration: sectionError != null
                        ? BoxDecoration(
                            borderRadius: ZxRadius.buttonAll,
                            border: Border.all(color: t.danger, width: 1.5),
                          )
                        : null,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final SectionItem section in _sections)
                          _ChannelChip(
                            key: Key('mobile-create-section-${section.key}'),
                            label: section.sectionName,
                            dot: t.channelFor(section.sectionName),
                            selected: _section == section,
                            onTap: () => setState(() => _section = section),
                          ),
                      ],
                    ),
                  ),
                if (sectionError != null && _sectionsLoadError == null)
                  _FieldError(sectionError),
              ],
            ),
          ),
          divider(),
          section(
            Column(
              key: _tagsKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading(
                  '标签',
                  trailing: Text(
                    '${_tags.length}/${PostLimits.tags}',
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final String tag in _tags)
                      InputChip(
                        label: Text('#$tag'),
                        labelStyle: ZxType.caption.copyWith(
                          fontSize: 13,
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: t.primarySoft,
                        side: BorderSide.none,
                        deleteIconColor: t.primary,
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                    ActionChip(
                      key: const Key('mobile-create-tags'),
                      avatar: Icon(Icons.add_rounded, size: 16, color: t.text2),
                      label: const Text('添加标签'),
                      onPressed: _editTags,
                    ),
                  ],
                ),
                if (tagError != null) _FieldError(tagError),
              ],
            ),
          ),
          divider(),
          section(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('状态'),
                _Segmented<PostStatus>(
                  keyPrefix: 'mobile-create-status',
                  value: _status,
                  options: const <(PostStatus, String)>[
                    (PostStatus.ongoing, '进行中'),
                    (PostStatus.resolved, '已解决'),
                    (PostStatus.closed, '已结束'),
                  ],
                  onChanged: (PostStatus s) => setState(() => _status = s),
                ),
              ],
            ),
          ),
          divider(),
          section(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('可见范围'),
                _Segmented<bool>(
                  keyPrefix: 'mobile-create-visibility',
                  value: _privateOnly,
                  options: const <(bool, String)>[
                    (false, '所有人'),
                    (true, '仅自己'),
                  ],
                  onChanged: (bool v) => setState(() => _privateOnly = v),
                ),
              ],
            ),
          ),
          divider(),
          section(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '匿名发布',
                            style: ZxType.label.copyWith(color: t.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '以印章代替头像，昵称可自定义',
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('mobile-create-anonymous'),
                      value: _isAnonymous,
                      onChanged: _setAnonymous,
                    ),
                  ],
                ),
                if (_isAnonymous) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: t.bgSunk,
                      borderRadius: ZxRadius.buttonAll,
                    ),
                    child: Row(
                      children: [
                        ZxAvatar.anonymous(
                          name: _aliasController.text.trim().isEmpty
                              ? '匿'
                              : _aliasController.text.trim(),
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _aliasController,
                            // sanitize_alias keeps 24 code points.
                            inputFormatters: const [
                              CodePointLimitFormatter(24),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: ZxType.body.copyWith(color: t.text),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              counterText: '',
                              hintText: '匿名昵称（选填）',
                              hintStyle: ZxType.body.copyWith(color: t.text3),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        ZxButton(
                          label: '随机',
                          icon: Icons.casino_outlined,
                          small: true,
                          variant: ZxButtonVariant.ghost,
                          onPressed: () => _fillRandomAlias(explicit: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLevelOneUser) ...[
            divider(),
            section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading('置顶时长', trailing: const ZxBadge.pinned('一级用户可用')),
                  _Segmented<int?>(
                    keyPrefix: 'mobile-create-pin',
                    value: _pinMinutes,
                    options: const <(int?, String)>[
                      (null, '不置顶'),
                      (60, '1 小时'),
                      (1440, '1 天'),
                      (4320, '3 天'),
                    ],
                    onChanged: (int? v) => setState(() => _pinMinutes = v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: t.danger),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message,
              style: ZxType.caption.copyWith(
                color: t.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 正在上传图片 2/3 · 66%, under the app bar while publishing (P3).
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.text, required this.value});

  final String text;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: ZxType.caption.copyWith(color: t.text2),
                ),
              ),
              if (value != null)
                Text(
                  '${(value! * 100).round()}%',
                  style: ZxType.caption.copyWith(color: t.text3),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 3,
              color: t.primary,
              backgroundColor: t.bgSunk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    super.key,
    required this.label,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Material(
      color: selected ? t.primarySoft : t.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? t.primary : t.lineStrong,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: ZxType.caption.copyWith(
                  fontSize: 13,
                  color: selected ? t.primary : t.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The handoff's segmented track: a sunk bar with the choice raised on it.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String keyPrefix;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.bgSunk,
        borderRadius: ZxRadius.buttonAll,
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key('$keyPrefix-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: options[i].$1 == value ? t.surface : null,
                    borderRadius: BorderRadius.circular(ZxRadius.smallButton),
                    boxShadow: options[i].$1 == value ? t.shadow1 : null,
                  ),
                  child: Text(
                    options[i].$2,
                    style: ZxType.caption.copyWith(
                      fontSize: 13,
                      color: options[i].$1 == value ? t.primary : t.text2,
                      fontWeight: options[i].$1 == value
                          ? FontWeight.w600
                          : FontWeight.w400,
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

/// Up to five tags: common ones to tap, or typed ones. Returns the choice.
class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.selected});

  final List<String> selected;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  static const int _max = PostLimits.tags;
  static const List<String> _common = <String>[
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

  late final List<String> _chosen = List<String>.of(widget.selected);
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    setState(() {
      if (_chosen.contains(tag)) {
        _chosen.remove(tag);
      } else if (_chosen.length < _max) {
        _chosen.add(tag);
      }
    });
  }

  void _addCustom() {
    final List<String> typed = _custom.text
        .split(RegExp(r'[,，\s#]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty && !_chosen.contains(s))
        .toList();
    if (typed.isEmpty) return;
    setState(() {
      _chosen.addAll(typed.take(_max - _chosen.length));
      _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final List<String> shown = <String>{..._chosen, ..._common}.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '标签 ${_chosen.length}/$_max',
                style: ZxType.title.copyWith(color: t.text),
              ),
              const Spacer(),
              ZxButton(
                key: const Key('mobile-create-tags-done'),
                label: '完成',
                small: true,
                onPressed: () => Navigator.of(context).pop(_chosen),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final String tag in shown)
                FilterChip(
                  showCheckmark: false,
                  label: Text('#$tag'),
                  selected: _chosen.contains(tag),
                  onSelected: (_) => _toggle(tag),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustom(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '自定义标签，空格分隔',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ZxButton(
                label: '添加',
                small: true,
                variant: ZxButtonVariant.secondary,
                onPressed: _chosen.length >= _max ? null : _addCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
