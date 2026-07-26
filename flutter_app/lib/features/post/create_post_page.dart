import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_store.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/markdown_clipboard_image.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/post_draft_store.dart';
import '../../core/state/web_theme_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/hashtag_text_editing_controller.dart';
import '../../models/post_item.dart';
import '../../models/uploaded_image_item.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/post_content_body.dart';
import 'create_post_controller.dart';

/// Opens the post composer as one centred, interruptible writing surface.
///
/// Publishing never replaces the current feed route, so closing the composer
/// returns the reader exactly to the place from which they started writing.
Future<bool?> showCreatePostComposer(BuildContext context) =>
    showAppDialog<bool>(
      context: context,
      maxWidth: 860,
      builder: (BuildContext context) => const CreatePostComposer(),
    );

class CreatePostComposer extends ConsumerStatefulWidget {
  const CreatePostComposer({super.key});

  @override
  ConsumerState<CreatePostComposer> createState() => _CreatePostComposerState();
}

class _CreatePostComposerState extends ConsumerState<CreatePostComposer> {
  static const int _plainTextMaxLength = 3000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final HashtagTextEditingController _contentController =
      HashtagTextEditingController();
  final TextEditingController _anonymousAliasController =
      TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  late final String _draftOwnerId;

  bool _useAnonymousAlias = false;
  bool _useMarkdown = false;
  bool _privateOnly = false;
  bool _showOptions = false;
  bool _pickingImages = false;
  bool _pastingMarkdownImages = false;
  MarkdownClipboardImageDetach? _detachMarkdownPasteListener;
  final List<PickedImageData> _pickedImages = <PickedImageData>[];
  final Map<String, String> _markdownImageUploadIdsByUrl = <String, String>{};

  @override
  void initState() {
    super.initState();
    _draftOwnerId = AuthStore.instance.currentUser!.userId.trim();
    _detachMarkdownPasteListener = registerMarkdownClipboardImageListener(
      focusNode: _contentFocusNode,
      onImagesPasted: _handleMarkdownImagesPasted,
    );
    Future<void>.microtask(
      () => ref.read(createPostControllerProvider.notifier).loadChannels(),
    );
    Future<void>.microtask(_restoreDraft);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _contentFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _detachMarkdownPasteListener?.call();
    _titleController.dispose();
    _contentController.dispose();
    _anonymousAliasController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreatePostState state = ref.watch(createPostControllerProvider);
    final ThemeData composerTheme = AppTheme.darkThemeFor(
      Localizations.localeOf(context),
      preset: WebThemeStore.instance.preset,
    );
    final EditorialColors colors = composerTheme.extension<EditorialColors>()!;
    final bool isBusy =
        state.submitting || _pickingImages || _pastingMarkdownImages;
    final bool compact = AppBreakpoints.isCompact(context);

    return Theme(
      data: composerTheme,
      child: PopScope(
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (didPop) {
            _saveDraft();
          }
        },
        child: Material(
          color: colors.composerSurface,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _ComposerHeader(busy: isBusy, onClose: _closeWithDraft),
                Divider(color: colors.line, height: 1),
                Expanded(
                  child: AsyncPageState(
                    loading: state.loadingChannels,
                    loadingLabel: '正在准备发布',
                    error: state.error,
                    onRetry: () => ref
                        .read(createPostControllerProvider.notifier)
                        .loadChannels(),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        key: const Key('create-post-form-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          compact ? AppSpacing.md : AppSpacing.xl,
                          AppSpacing.lg,
                          compact ? AppSpacing.md : AppSpacing.xl,
                          AppSpacing.xl,
                        ),
                        children: <Widget>[
                          if (isBusy) ...<Widget>[
                            _ComposerProgress(
                              text: _pastingMarkdownImages
                                  ? '正在上传粘贴的图片'
                                  : _pickingImages
                                  ? '正在读取图片'
                                  : (state.progressText ?? '正在发布'),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _ComposerIdentity(
                            nickname:
                                AuthStore.instance.currentUser?.nickname
                                    .trim() ??
                                '',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ThreadComposerFields(
                            titleController: _titleController,
                            contentController: _contentController,
                            contentFocusNode: _contentFocusNode,
                            useMarkdown: _useMarkdown,
                            maxLength: _plainTextMaxLength,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Tooltip(
                                message: '添加图片',
                                child: IconButton(
                                  onPressed: isBusy ? null : _pickImages,
                                  icon: const Icon(Icons.image_outlined),
                                ),
                              ),
                              EmojiAssistantBar(
                                controller: _contentController,
                                compact: true,
                              ),
                              Tooltip(
                                message: _useMarkdown
                                    ? '退出 Markdown'
                                    : 'Markdown',
                                child: IconButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => _handleMarkdownToggle(
                                          !_useMarkdown,
                                        ),
                                  color: _useMarkdown ? colors.primary : null,
                                  icon: const Icon(Icons.code_rounded),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_pickedImages.length}/9',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: colors.faintInk),
                              ),
                            ],
                          ),
                          if (_pickedImages.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            _PickedImageStrip(
                              images: _pickedImages,
                              disabled: isBusy,
                              onRemove: (int index) =>
                                  setState(() => _pickedImages.removeAt(index)),
                            ),
                          ],
                          if (_useMarkdown) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            _MarkdownPreview(controller: _contentController),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Divider(color: colors.line, height: 1),
                          _ComposerOptionsToggle(
                            expanded: _showOptions,
                            onTap: isBusy
                                ? null
                                : () => setState(
                                    () => _showOptions = !_showOptions,
                                  ),
                          ),
                          if (_showOptions)
                            _PostOptions(
                              isBusy: isBusy,
                              useAnonymousAlias: _useAnonymousAlias,
                              privateOnly: _privateOnly,
                              anonymousAliasController:
                                  _anonymousAliasController,
                              onAnonymousChanged: (bool value) =>
                                  setState(() => _useAnonymousAlias = value),
                              onVisibilityChanged: (String? value) => setState(
                                () => _privateOnly = value == 'private',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(color: colors.line, height: 1),
                _ComposerFooter(
                  isBusy: isBusy,
                  onClose: _closeWithDraft,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreDraft() async {
    final PostDraft? draft = await PostDraftStore.load(userId: _draftOwnerId);
    if (!mounted || draft == null) return;
    setState(() {
      _titleController.text = draft.title;
      _contentController.text = draft.content;
      _anonymousAliasController.text = draft.anonymousAlias;
      _useAnonymousAlias = draft.useAnonymousAlias;
      _useMarkdown = draft.useMarkdown;
      _privateOnly = draft.privateOnly;
    });
    _contentController.highlightHashtags = !draft.useMarkdown;
  }

  Future<void> _saveDraft() => PostDraftStore.save(
    userId: _draftOwnerId,
    draft: PostDraft(
      title: _titleController.text,
      content: _contentController.text,
      anonymousAlias: _anonymousAliasController.text,
      useAnonymousAlias: _useAnonymousAlias,
      useMarkdown: _useMarkdown,
      privateOnly: _privateOnly,
    ),
  );

  Future<void> _closeWithDraft() async {
    await _saveDraft();
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _pickImages() async {
    if (_pickingImages) return;
    setState(() => _pickingImages = true);

    try {
      final List<PickedImageData> selected = await pickImageFiles(
        multiple: true,
      );
      if (!mounted || selected.isEmpty) return;

      const int maxImages = 9;
      final int remaining = maxImages - _pickedImages.length;
      if (remaining <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('最多上传 9 张图片')));
        return;
      }

      final List<PickedImageData> accepted = selected.take(remaining).toList();
      setState(() => _pickedImages.addAll(accepted));

      if (selected.length > accepted.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '最多上传 9 张图片，未添加 ${selected.length - accepted.length} 张。',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择图片失败：$error')));
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _pruneMarkdownImageMappings();
    final String rawContent = _contentController.text;
    final String submittedContent = _useMarkdown
        ? rawContent
        : rawContent.trim();
    final List<UploadPayload> uploadPayloads = _pickedImages
        .map(
          (PickedImageData image) => UploadPayload(
            fileName: image.fileName,
            contentType: image.contentType,
            dataBase64: image.dataBase64,
            sizeBytes: image.sizeBytes,
          ),
        )
        .toList();
    final PostItem? created = await ref
        .read(createPostControllerProvider.notifier)
        .submit(
          title: _titleController.text.trim(),
          content: submittedContent,
          useMarkdown: _useMarkdown,
          privateOnly: _privateOnly,
          useAnonymousAlias: _useAnonymousAlias,
          anonymousAlias: _useAnonymousAlias
              ? _anonymousAliasController.text.trim()
              : null,
          uploadPayloads: uploadPayloads,
          preUploadedImageIds: _useMarkdown
              ? _markdownImageUploadIdsByUrl.values.toList()
              : const <String>[],
        );

    if (!mounted || created == null) return;
    await PostDraftStore.clear(userId: _draftOwnerId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('帖子已发布。')));
    Navigator.of(context).pop(true);
  }

  void _handleMarkdownToggle(bool value) {
    if (_useMarkdown == value) return;
    _contentController.highlightHashtags = !value;
    setState(() {
      _useMarkdown = value;
    });
  }

  Future<void> _handleMarkdownImagesPasted(List<PickedImageData> images) async {
    if (!_useMarkdown || !mounted || images.isEmpty) return;

    _pruneMarkdownImageMappings();
    const int maxImages = 9;
    final int remaining =
        maxImages -
        (_pickedImages.length + _markdownImageUploadIdsByUrl.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多上传 9 张图片')));
      return;
    }

    final List<PickedImageData> accepted = images.take(remaining).toList();
    if (accepted.isEmpty) return;

    setState(() => _pastingMarkdownImages = true);
    try {
      final List<String> snippets = <String>[];
      for (final PickedImageData image in accepted) {
        final UploadedImageItem uploaded = await ref
            .read(postRepositoryProvider)
            .uploadImage(
              fileName: image.fileName,
              contentType: image.contentType,
              dataBase64: image.dataBase64,
            );
        final String alt = _deriveMarkdownImageAlt(image.fileName);
        snippets.add('![$alt](${uploaded.url})');
        _markdownImageUploadIdsByUrl[uploaded.url] = uploaded.id;
      }
      _insertMarkdownSnippet(snippets.join('\n\n'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('粘贴图片失败：$error')));
    } finally {
      if (mounted) setState(() => _pastingMarkdownImages = false);
    }
  }

  void _insertMarkdownSnippet(String snippet) {
    final TextEditingValue currentValue = _contentController.value;
    final TextSelection selection = currentValue.selection.isValid
        ? currentValue.selection
        : TextSelection.collapsed(offset: currentValue.text.length);
    final int start = selection.start.clamp(0, currentValue.text.length);
    final int end = selection.end.clamp(0, currentValue.text.length);
    final String before = currentValue.text.substring(0, start);
    final String after = currentValue.text.substring(end);

    String inserted = snippet;
    if (before.isNotEmpty && !before.endsWith('\n')) inserted = '\n\n$inserted';
    if (after.isNotEmpty && !after.startsWith('\n')) inserted = '$inserted\n\n';

    final String nextText = '$before$inserted$after';
    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: (before + inserted).length),
    );
  }

  void _pruneMarkdownImageMappings() {
    final String source = _contentController.text;
    _markdownImageUploadIdsByUrl.removeWhere(
      (String url, String _) => !source.contains(url),
    );
  }

  String _deriveMarkdownImageAlt(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) return '图片';
    final int dotIndex = trimmed.lastIndexOf('.');
    final String baseName = dotIndex > 0
        ? trimmed.substring(0, dotIndex)
        : trimmed;
    return baseName.trim().isEmpty ? '图片' : baseName.trim();
  }
}

class _ComposerHeader extends StatelessWidget {
  const _ComposerHeader({required this.busy, required this.onClose});

  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : onClose,
              child: const Text('取消'),
            ),
          ),
          Text('发布帖子', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ComposerIdentity extends StatelessWidget {
  const _ComposerIdentity({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String initial = nickname.isEmpty ? '我' : nickname.characters.first;
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 21,
          backgroundColor: colors.primarySubtle,
          foregroundColor: colors.primary,
          child: Text(initial, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          nickname.isEmpty ? '我' : nickname,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _ThreadComposerFields extends StatelessWidget {
  const _ThreadComposerFields({
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.useMarkdown,
    required this.maxLength,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final bool useMarkdown;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.tab):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.tab, shift: true):
            DoNothingAndStopPropagationIntent(),
      },
      child: Column(
        children: <Widget>[
          TextFormField(
            key: const Key('create-post-title'),
            controller: titleController,
            maxLength: 60,
            style: AppTypography.postContentStyle(
              Theme.of(context).textTheme.titleMedium,
            ),
            decoration: AppInput.decoration(
              hintText: '标题',
              counterMaxLength: 60,
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) return '请输入标题';
              if (value.trim().length < 4) return '标题至少 4 个字';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: ValueKey<String>(
              useMarkdown
                  ? 'create-post-markdown-editor'
                  : 'create-post-plain-editor',
            ),
            controller: contentController,
            focusNode: contentFocusNode,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 7,
            maxLines: 12,
            maxLength: useMarkdown ? null : maxLength,
            maxLengthEnforcement: useMarkdown
                ? null
                : MaxLengthEnforcement.enforced,
            autocorrect: !useMarkdown,
            enableSuggestions: !useMarkdown,
            enableIMEPersonalizedLearning: !useMarkdown,
            style: useMarkdown
                ? null
                : AppTypography.postContentStyle(
                    Theme.of(context).textTheme.bodyLarge,
                  ),
            smartDashesType: useMarkdown
                ? SmartDashesType.disabled
                : SmartDashesType.enabled,
            smartQuotesType: useMarkdown
                ? SmartQuotesType.disabled
                : SmartQuotesType.enabled,
            spellCheckConfiguration: useMarkdown
                ? const SpellCheckConfiguration.disabled()
                : null,
            decoration: AppInput.decoration(
              hintText: useMarkdown ? '使用 Markdown 书写内容' : '说说新鲜事…',
              counterMaxLength: useMarkdown ? null : maxLength,
            ).copyWith(alignLabelWithHint: true),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) return '请输入正文';
              if (value.trim().length < 8) return '正文至少 8 个字';
              if (!useMarkdown && value.length > maxLength) {
                return '正文最多 $maxLength 字';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _ComposerProgress extends StatelessWidget {
  const _ComposerProgress({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _PickedImageStrip extends StatelessWidget {
  const _PickedImageStrip({
    required this.images,
    required this.disabled,
    required this.onRemove,
  });

  final List<PickedImageData> images;
  final bool disabled;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: images
        .asMap()
        .entries
        .map(
          (MapEntry<int, PickedImageData> entry) => _PickedImageTile(
            image: entry.value,
            onRemove: disabled ? null : () => onRemove(entry.key),
          ),
        )
        .toList(growable: false),
  );
}

class _PickedImageTile extends StatelessWidget {
  const _PickedImageTile({required this.image, required this.onRemove});

  final PickedImageData image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.memory(base64Decode(image.dataBase64), fit: BoxFit.cover),
            Positioned(
              top: AppSpacing.xxs,
              right: AppSpacing.xxs,
              child: IconButton(
                onPressed: onRemove,
                tooltip: '移除图片',
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  backgroundColor: colors.darkPanel.withValues(alpha: 0.76),
                  foregroundColor: colors.onDarkPanel,
                ),
                iconSize: 16,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder:
              (BuildContext context, TextEditingValue value, Widget? child) {
                final String source = value.text.trim();
                if (source.isEmpty) return const SizedBox.shrink();
                return PostContentBody(
                  content: '',
                  contentFormat: 'markdown',
                  markdownSource: source,
                  selectable: false,
                );
              },
        ),
      ),
    );
  }
}

class _ComposerOptionsToggle extends StatelessWidget {
  const _ComposerOptionsToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(expanded ? Icons.expand_less_rounded : Icons.tune_rounded),
    label: const Text('发布选项'),
  );
}

class _PostOptions extends StatelessWidget {
  const _PostOptions({
    required this.isBusy,
    required this.useAnonymousAlias,
    required this.privateOnly,
    required this.anonymousAliasController,
    required this.onAnonymousChanged,
    required this.onVisibilityChanged,
  });

  final bool isBusy;
  final bool useAnonymousAlias;
  final bool privateOnly;
  final TextEditingController anonymousAliasController;
  final ValueChanged<bool> onAnonymousChanged;
  final ValueChanged<String?> onVisibilityChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SwitchListTile(
        value: useAnonymousAlias,
        onChanged: isBusy ? null : onAnonymousChanged,
        title: const Text('匿名发布'),
        contentPadding: EdgeInsets.zero,
      ),
      if (useAnonymousAlias) ...<Widget>[
        TextFormField(
          controller: anonymousAliasController,
          decoration: AppInput.decoration(hintText: '匿名昵称（可选）'),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) return null;
            if (value.trim().length > 24) return '匿名昵称最长 24 个字符';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      DropdownButtonFormField<String>(
        initialValue: privateOnly ? 'private' : 'public',
        decoration: AppInput.decoration(hintText: '可见范围'),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'public', child: Text('所有人可见')),
          DropdownMenuItem<String>(value: 'private', child: Text('仅自己可见')),
        ],
        onChanged: isBusy ? null : onVisibilityChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
    ],
  );
}

class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.isBusy,
    required this.onClose,
    required this.onSubmit,
  });

  final bool isBusy;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        TextButton(onPressed: isBusy ? null : onClose, child: const Text('取消')),
        const Spacer(),
        FilledButton(
          key: const Key('create-post-submit'),
          onPressed: isBusy ? null : onSubmit,
          child: Text(isBusy ? '发布中…' : '发布'),
        ),
      ],
    ),
  );
}
