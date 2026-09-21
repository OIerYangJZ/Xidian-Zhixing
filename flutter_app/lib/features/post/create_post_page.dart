import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/markdown_clipboard_image.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/async_page_state.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/post_item.dart';
import '../../models/uploaded_image_item.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/post_content_body.dart';
import 'create_post_controller.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  static const int _plainTextMaxLength = 3000;
  static const String _draftKey = 'xiaodian_create_post_draft';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _anonymousAliasController =
      TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  String? _selectedChannel;
  PostStatus _status = PostStatus.ongoing;
  bool _useAnonymousAlias = false;
  bool _useMarkdown = false;
  String _plainDraft = '';
  String _markdownDraft = '';
  bool _privateOnly = false;
  int? _selectedPinDurationMinutes;
  bool _pickingImages = false;
  bool _pastingMarkdownImages = false;
  MarkdownClipboardImageDetach? _detachMarkdownPasteListener;
  final List<PickedImageData> _pickedImages = <PickedImageData>[];
  final Map<String, String> _markdownImageUploadIdsByUrl = <String, String>{};

  @override
  void initState() {
    super.initState();
    _detachMarkdownPasteListener = registerMarkdownClipboardImageListener(
      focusNode: _contentFocusNode,
      onImagesPasted: _handleMarkdownImagesPasted,
    );
    unawaited(_loadDraft());
    Future<void>.microtask(
      () => ref.read(createPostControllerProvider.notifier).loadChannels(),
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
    final Locale locale = Localizations.localeOf(context);
    final CreatePostState state = ref.watch(createPostControllerProvider);
    final bool isBusy =
        state.submitting || _pickingImages || _pastingMarkdownImages;
    final List<String> channels = state.channels;
    final bool hasChannels = channels.isNotEmpty;
    final String? selectedChannel = hasChannels
        ? _deriveSelectedChannel(channels)
        : null;

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(_saveDraft());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(uiText(context, zh: '发布帖子', en: 'New post')),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.readingMaxWidth,
            ),
            child: AsyncPageState(
              loading: state.loadingChannels,
              loadingLabel: uiText(
                context,
                zh: '正在准备发布表单',
                en: 'Preparing the compose form',
              ),
              error: state.error,
              onRetry: () => ref
                  .read(createPostControllerProvider.notifier)
                  .loadChannels(),
              child: ListView(
                key: const Key('create-post-form-scroll'),
                padding: AppLayout.pagePadding(context),
                children: <Widget>[
                  if (isBusy)
                    _ProgressCard(
                      text: _pastingMarkdownImages
                          ? uiText(
                              context,
                              zh: '上传粘贴图片中...',
                              en: 'Uploading pasted images...',
                            )
                          : _pickingImages
                          ? uiText(
                              context,
                              zh: '读取图片中...',
                              en: 'Reading images...',
                            )
                          : (state.progressText ??
                                uiText(
                                  context,
                                  zh: '提交中...',
                                  en: 'Submitting...',
                                )),
                    ),
                  if (isBusy) const SizedBox(height: AppSpacing.sm),
                  AppSurfaceCard(
                    padding: EdgeInsets.all(
                      AppBreakpoints.isCompact(context)
                          ? AppSpacing.md
                          : AppSpacing.lg,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Shortcuts(
                            shortcuts: const <ShortcutActivator, Intent>{
                              SingleActivator(LogicalKeyboardKey.tab):
                                  DoNothingAndStopPropagationIntent(),
                              SingleActivator(
                                LogicalKeyboardKey.tab,
                                shift: true,
                              ): DoNothingAndStopPropagationIntent(),
                            },
                            child: TextFormField(
                              key: const Key('create-post-title'),
                              controller: _titleController,
                              maxLength: 60,
                              decoration: InputDecoration(
                                labelText: uiText(
                                  context,
                                  zh: '标题',
                                  en: 'Title',
                                ),
                                hintText: uiText(
                                  context,
                                  zh: '一句话概括你的问题或诉求',
                                  en: 'Sum up your question or request in one line',
                                ),
                              ),
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return uiTextFor(
                                    locale,
                                    zh: '请输入标题',
                                    en: 'Please enter a title',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            value: _useMarkdown,
                            onChanged: isBusy ? null : _handleMarkdownToggle,
                            title: Text(
                              uiText(
                                context,
                                zh: '使用 Markdown 编辑',
                                en: 'Compose in Markdown',
                              ),
                            ),
                            subtitle: Text(
                              uiText(
                                context,
                                zh: '开启后可编写 Markdown 源码，发出后按渲染效果展示',
                                en: 'Write Markdown source; the post renders it once published',
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: ValueKey<String>(
                              _useMarkdown
                                  ? 'create-post-markdown-editor'
                                  : 'create-post-plain-editor',
                            ),
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 6,
                            maxLines: 10,
                            maxLength: _useMarkdown
                                ? null
                                : _plainTextMaxLength,
                            maxLengthEnforcement: _useMarkdown
                                ? null
                                : MaxLengthEnforcement.enforced,
                            autocorrect: !_useMarkdown,
                            enableSuggestions: !_useMarkdown,
                            enableIMEPersonalizedLearning: !_useMarkdown,
                            smartDashesType: _useMarkdown
                                ? SmartDashesType.disabled
                                : SmartDashesType.enabled,
                            smartQuotesType: _useMarkdown
                                ? SmartQuotesType.disabled
                                : SmartQuotesType.enabled,
                            spellCheckConfiguration: _useMarkdown
                                ? const SpellCheckConfiguration.disabled()
                                : null,
                            decoration: InputDecoration(
                              alignLabelWithHint: true,
                              labelText: _useMarkdown
                                  ? uiText(
                                      context,
                                      zh: 'Markdown 源码',
                                      en: 'Markdown source',
                                    )
                                  : uiText(context, zh: '正文', en: 'Body'),
                              hintText: _useMarkdown
                                  ? uiText(
                                      context,
                                      zh: '# 标题\n- 列表项\n> 引用\n```dart\nprint("Hello");\n```',
                                      en: '# Heading\n- List item\n> Quote\n```dart\nprint("Hello");\n```',
                                    )
                                  : uiText(
                                      context,
                                      zh: '描述越完整，越容易获得帮助',
                                      en: 'The more detail you give, the easier it is to help',
                                    ),
                              helperText: _useMarkdown
                                  ? uiText(
                                      context,
                                      zh: '支持直接粘贴图片并自动插入链接。',
                                      en: 'Paste images directly and insert their links automatically.',
                                    )
                                  : uiText(
                                      context,
                                      zh: '纯文本正文最多 3000 字。',
                                      en: 'Plain text is limited to 3000 characters.',
                                    ),
                              helperMaxLines: 2,
                            ),
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return uiTextFor(
                                  locale,
                                  zh: '请输入正文',
                                  en: 'Please enter the body',
                                );
                              }
                              if (!_useMarkdown &&
                                  value.length > _plainTextMaxLength) {
                                return uiTextFor(
                                  locale,
                                  zh: '纯文本正文最多 $_plainTextMaxLength 字',
                                  en: 'Plain text is limited to $_plainTextMaxLength characters',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 4),
                          EmojiAssistantBar(
                            controller: _contentController,
                            compact: true,
                          ),
                          if (_useMarkdown) ...<Widget>[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    uiText(
                                      context,
                                      zh: '实时预览',
                                      en: 'Live preview',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _contentController,
                                    builder:
                                        (
                                          BuildContext context,
                                          TextEditingValue value,
                                          Widget? child,
                                        ) {
                                          final String source = value.text
                                              .trim();
                                          if (source.isEmpty) {
                                            return Text(
                                              uiText(
                                                context,
                                                zh: '输入 Markdown 源码后，这里会显示渲染效果。',
                                                en: 'Type Markdown source and the rendered result appears here.',
                                              ),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.58),
                                              ),
                                            );
                                          }
                                          return PostContentBody(
                                            content: '',
                                            contentFormat: 'markdown',
                                            markdownSource: source,
                                            selectable: false,
                                          );
                                        },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (hasChannels)
                            DropdownButtonFormField<String>(
                              initialValue: selectedChannel,
                              decoration: InputDecoration(
                                labelText: uiText(
                                  context,
                                  zh: '频道',
                                  en: 'Channel',
                                ),
                              ),
                              items: channels
                                  .map(
                                    (String channel) =>
                                        DropdownMenuItem<String>(
                                          value: channel,
                                          child: Text(
                                            localizedChannel(locale, channel),
                                          ),
                                        ),
                                  )
                                  .toList(),
                              onChanged: isBusy
                                  ? null
                                  : (String? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedChannel = value;
                                      });
                                    },
                            )
                          else
                            const _EmptyChannelCard(),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<PostStatus>(
                            initialValue: _status,
                            decoration: InputDecoration(
                              labelText: uiText(
                                context,
                                zh: '状态',
                                en: 'Status',
                              ),
                            ),
                            items: PostStatus.values
                                .map(
                                  (PostStatus status) =>
                                      DropdownMenuItem<PostStatus>(
                                        value: status,
                                        child: Text(status.labelFor(locale)),
                                      ),
                                )
                                .toList(),
                            onChanged: isBusy
                                ? null
                                : (PostStatus? value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _status = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            value: _useAnonymousAlias,
                            onChanged: isBusy
                                ? null
                                : (bool value) {
                                    setState(() {
                                      _useAnonymousAlias = value;
                                    });
                                  },
                            title: Text(
                              uiText(
                                context,
                                zh: '本帖使用匿名身份',
                                en: 'Post anonymously',
                              ),
                            ),
                            subtitle: Text(
                              uiText(
                                context,
                                zh: '仅影响当前帖子，不影响你的账号昵称',
                                en: 'Affects this post only, not your account nickname',
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_useAnonymousAlias) ...<Widget>[
                            TextFormField(
                              controller: _anonymousAliasController,
                              decoration: InputDecoration(
                                labelText: uiText(
                                  context,
                                  zh: '匿名昵称（可选）',
                                  en: 'Anonymous nickname (optional)',
                                ),
                                hintText: uiText(
                                  context,
                                  zh: '例如：热心同学',
                                  en: 'e.g. Helpful classmate',
                                ),
                              ),
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                if (value.trim().length > 24) {
                                  return uiTextFor(
                                    locale,
                                    zh: '匿名昵称最长 24 个字符',
                                    en: 'The anonymous nickname is limited to 24 characters',
                                  );
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _privateOnly ? 'private' : 'public',
                            decoration: InputDecoration(
                              labelText: uiText(
                                context,
                                zh: '可见范围',
                                en: 'Visibility',
                              ),
                            ),
                            items: <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'public',
                                child: Text(
                                  uiText(
                                    context,
                                    zh: '所有人可见',
                                    en: 'Visible to everyone',
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'private',
                                child: Text(
                                  uiText(
                                    context,
                                    zh: '仅自己可见',
                                    en: 'Visible only to me',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: isBusy
                                ? null
                                : (String? value) {
                                    setState(() {
                                      _privateOnly = value == 'private';
                                    });
                                  },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _privateOnly
                                ? uiText(
                                    context,
                                    zh: '仅你自己能在“我的帖子”里看到这条内容。',
                                    en: 'Only you can see this post, under “My posts”.',
                                  )
                                : uiText(
                                    context,
                                    zh: '公开帖子中，不匿名且你开启“允许陌生人私信”时，其他人可直接私信你。',
                                    en: 'On a public, non-anonymous post, others can message you directly if you allow messages from strangers.',
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.58),
                            ),
                          ),
                          const Divider(height: 28),
                          Row(
                            children: <Widget>[
                              Text(
                                uiText(
                                  context,
                                  zh: '图片（${_pickedImages.length}/20）',
                                  en: 'Images (${_pickedImages.length}/20)',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: isBusy ? null : _pickImages,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: Text(
                                  uiText(
                                    context,
                                    zh: '选择图片',
                                    en: 'Choose images',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_pickedImages.isEmpty)
                            Text(
                              uiText(
                                context,
                                zh: '未选择图片。支持 jpg/png/webp/gif。',
                                en: 'No images selected. jpg / png / webp / gif are supported.',
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.58),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _pickedImages
                                  .asMap()
                                  .entries
                                  .map(
                                    (MapEntry<int, PickedImageData> entry) =>
                                        _PickedImageCard(
                                          image: entry.value,
                                          onRemove: isBusy
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _pickedImages.removeAt(
                                                      entry.key,
                                                    );
                                                  });
                                                },
                                        ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('create-post-submit'),
                              onPressed: isBusy || selectedChannel == null
                                  ? null
                                  : () => _submit(selectedChannel),
                              icon: const Icon(Icons.send_rounded),
                              label: Text(
                                state.submitting
                                    ? uiText(
                                        context,
                                        zh: '发布中...',
                                        en: 'Publishing...',
                                      )
                                    : uiText(
                                        context,
                                        zh: '发布帖子',
                                        en: 'Publish post',
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _loadDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_draftKey) ?? '';
    if (raw.trim().isEmpty) {
      return;
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }
    if (!mounted) {
      return;
    }
    final Map<String, dynamic> draft = Map<String, dynamic>.from(decoded);
    final String title = draft['title']?.toString() ?? '';
    final String content = draft['content']?.toString() ?? '';
    final bool markdown = draft['markdown'] == true;
    setState(() {
      _titleController.text = title;
      _useMarkdown = markdown;
      _plainDraft = markdown ? '' : content;
      _markdownDraft = markdown ? content : '';
      _contentController.text = content;
      _selectedChannel = draft['channel']?.toString();
      _privateOnly = draft['privateOnly'] == true;
      _useAnonymousAlias = draft['anonymous'] == true;
      _anonymousAliasController.text =
          draft['anonymousAlias']?.toString() ?? '';
      final String status = draft['status']?.toString() ?? '';
      _status = PostStatus.values.firstWhere(
        (PostStatus item) => item.name == status,
        orElse: () => PostStatus.ongoing,
      );
    });
  }

  Future<void> _saveDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String title = _titleController.text.trim();
    final String content = _contentController.text;
    if (title.isEmpty && content.trim().isEmpty) {
      await prefs.remove(_draftKey);
      return;
    }
    await prefs.setString(
      _draftKey,
      jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'markdown': _useMarkdown,
        'channel': _selectedChannel,
        'status': _status.name,
        'privateOnly': _privateOnly,
        'anonymous': _useAnonymousAlias,
        'anonymousAlias': _anonymousAliasController.text,
      }),
    );
  }

  Future<void> _clearDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _deriveSelectedChannel(List<String> channels) {
    if (_selectedChannel != null && channels.contains(_selectedChannel)) {
      return _selectedChannel!;
    }
    final String fallback = channels.first;
    _selectedChannel = fallback;
    return fallback;
  }

  Future<void> _pickImages() async {
    if (_pickingImages) {
      return;
    }
    setState(() {
      _pickingImages = true;
    });

    try {
      final List<PickedImageData> selected = await pickImageFiles(
        multiple: true,
      );
      if (!mounted || selected.isEmpty) {
        return;
      }

      const int maxImages = 20;
      final int remaining = maxImages - _pickedImages.length;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '最多上传 20 张图片',
                en: 'You can upload up to 20 images',
              ),
            ),
          ),
        );
        return;
      }

      final List<PickedImageData> accepted = selected.take(remaining).toList();
      setState(() {
        _pickedImages.addAll(accepted);
      });

      if (selected.length > accepted.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '最多上传 20 张图片，已自动保留前 $remaining 张。超出 ${selected.length - accepted.length} 张未选中。',
                en: 'Up to 20 images: kept the first $remaining, skipped ${selected.length - accepted.length}.',
              ),
            ),
          ),
        );
      }

      // 检查是否有大文件
      final List<PickedImageData> largeFiles = accepted
          .where((PickedImageData img) => img.sizeBytes > 5 * 1024 * 1024)
          .toList();
      if (largeFiles.isNotEmpty && accepted.length == remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '提示：${largeFiles.length} 张图片超过 5MB，可能上传较慢。',
                en: 'Heads up: ${largeFiles.length} image(s) exceed 5MB and may upload slowly.',
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '选择图片失败：$error',
              en: 'Could not select images: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingImages = false;
        });
      }
    }
  }

  Future<void> _submit(String selectedChannel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
    final CreatePostState state = ref.read(createPostControllerProvider);

    final PostItem? created = await ref
        .read(createPostControllerProvider.notifier)
        .submit(
          title: _titleController.text.trim(),
          content: submittedContent,
          useMarkdown: _useMarkdown,
          channel: selectedChannel,
          tags: const <String>[],
          privateOnly: _privateOnly,
          status: _status,
          useAnonymousAlias: _useAnonymousAlias,
          anonymousAlias: _useAnonymousAlias
              ? _anonymousAliasController.text.trim()
              : null,
          pinDurationMinutes: state.isLevelOneUser
              ? _selectedPinDurationMinutes
              : null,
          uploadPayloads: uploadPayloads,
          preUploadedImageIds: _useMarkdown
              ? _markdownImageUploadIdsByUrl.values.toList()
              : const <String>[],
        );

    if (!mounted || created == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created.isPinned
              ? uiText(
                  context,
                  zh: '帖子发布成功，已置顶展示。',
                  en: 'Post published and pinned.',
                )
              : uiText(
                  context,
                  zh: '帖子发布成功，已立即展示。',
                  en: 'Post published and live.',
                ),
        ),
      ),
    );
    await _clearDraft();
    Navigator.of(context).pop(true);
  }

  void _handleMarkdownToggle(bool value) {
    if (_useMarkdown == value) {
      return;
    }
    setState(() {
      if (_useMarkdown) {
        _markdownDraft = _contentController.text;
      } else {
        _plainDraft = _contentController.text;
      }
      _useMarkdown = value;
      final String nextDraft = value ? _markdownDraft : _plainDraft;
      _contentController.value = TextEditingValue(
        text: nextDraft,
        selection: TextSelection.collapsed(offset: nextDraft.length),
      );
    });
  }

  Future<void> _handleMarkdownImagesPasted(List<PickedImageData> images) async {
    if (!_useMarkdown || !mounted || images.isEmpty) {
      return;
    }

    _pruneMarkdownImageMappings();
    const int maxImages = 20;
    final int remaining =
        maxImages -
        (_pickedImages.length + _markdownImageUploadIdsByUrl.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '最多上传 20 张图片',
              en: 'You can upload up to 20 images',
            ),
          ),
        ),
      );
      return;
    }

    final List<PickedImageData> accepted = images.take(remaining).toList();
    if (accepted.isEmpty) {
      return;
    }

    setState(() {
      _pastingMarkdownImages = true;
    });

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

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '已插入 ${accepted.length} 张 Markdown 图片',
                en: 'Inserted ${accepted.length} Markdown image(s)',
              ),
            ),
          ),
        );
      if (images.length > accepted.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '最多上传 20 张图片，超出 ${images.length - accepted.length} 张未插入。',
                en: 'Up to 20 images: ${images.length - accepted.length} were not inserted.',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '粘贴图片失败：$error',
                en: 'Could not paste images: $error',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _pastingMarkdownImages = false;
        });
      }
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
    if (before.isNotEmpty && !before.endsWith('\n')) {
      inserted = '\n\n$inserted';
    }
    if (after.isNotEmpty && !after.startsWith('\n')) {
      inserted = '$inserted\n\n';
    }

    final String nextText = '$before$inserted$after';
    final int caretOffset = (before + inserted).length;
    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
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
    if (trimmed.isEmpty) {
      return uiTextGlobal(zh: '图片', en: 'image');
    }
    final int dotIndex = trimmed.lastIndexOf('.');
    final String baseName = dotIndex > 0
        ? trimmed.substring(0, dotIndex)
        : trimmed;
    final String sanitized = baseName.trim();
    return sanitized.isEmpty ? uiTextGlobal(zh: '图片', en: 'image') : sanitized;
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _EmptyChannelCard extends StatelessWidget {
  const _EmptyChannelCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.category_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uiText(context, zh: '暂无可用频道', en: 'No channels available'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedImageCard extends StatelessWidget {
  const _PickedImageCard({required this.image, required this.onRemove});

  final PickedImageData image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    try {
      preview = Image.memory(
        base64Decode(image.dataBase64),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 92,
      );
    } catch (_) {
      preview = Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      );
    }

    final String sizeStr = _formatFileSize(image.sizeBytes);
    final bool isLargeFile = image.sizeBytes > 5 * 1024 * 1024;

    return SizedBox(
      width: 140,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 92,
                      child: preview,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: onRemove,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isLargeFile)
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sizeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                image.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (!isLargeFile)
                Text(
                  sizeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
