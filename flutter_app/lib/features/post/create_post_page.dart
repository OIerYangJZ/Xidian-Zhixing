import 'dart:async';
import '../../core/utils/code_point_limit.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/markdown_clipboard_image.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../models/section_item.dart';
import '../../repositories/post_repository.dart' show PostLimits;
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
  static const int _plainTextMaxLength = PostLimits.plainContent;
  static const String _draftKey = 'xiaodian_create_post_draft';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _anonymousAliasController =
      TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  /// A section's key; the draft keeps it across visits.
  String? _selectedSectionKey;
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
  final List<String> _tags = <String>[];
  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _contentFieldKey = GlobalKey();
  final GlobalKey _sectionFieldKey = GlobalKey();
  final GlobalKey _tagsFieldKey = GlobalKey();
  Timer? _draftTimer;
  DateTime? _draftSavedAt;

  /// Set after a publish attempt, so errors show only once the user tried.
  bool _showErrors = false;

  /// Narrow Markdown layout: 编辑 or 预览.
  bool _showPreview = false;

  static const int _maxTags = PostLimits.tags;

  /// Must match the server's PIN_DURATION_OPTIONS; it rejects anything else.
  static const List<(int?, String, String)> _pinOptions =
      <(int?, String, String)>[
        (null, '不置顶', 'None'),
        (30, '30 分钟', '30 min'),
        (60, '1 小时', '1 h'),
        (120, '2 小时', '2 h'),
        (180, '3 小时', '3 h'),
        (1440, '1 天', '1 day'),
        (4320, '3 天', '3 days'),
      ];
  final Map<String, String> _markdownImageUploadIdsByUrl = <String, String>{};

  /// Every image the post will carry: the picked ones, plus in Markdown mode
  /// those uploaded into the text. The server takes at most 9 in all.
  int get _imageCount =>
      _pickedImages.length +
      (_useMarkdown ? _markdownImageUploadIdsByUrl.length : 0);

  @override
  void initState() {
    super.initState();
    _detachMarkdownPasteListener = registerMarkdownClipboardImageListener(
      focusNode: _contentFocusNode,
      onImagesPasted: _handleMarkdownImagesPasted,
    );
    unawaited(_loadDraft());
    // Drafts save after each pause in typing, not only on leaving the page.
    for (final TextEditingController controller in <TextEditingController>[
      _titleController,
      _contentController,
      _anonymousAliasController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    Future<void>.microtask(
      () => ref.read(createPostControllerProvider.notifier).loadSections(),
    );
  }

  Future<void> _fillRandomAlias() async {
    try {
      final String alias = await ref
          .read(postRepositoryProvider)
          .fetchRandomAnonymousAlias();
      if (!mounted) return;
      _anonymousAliasController.text = alias;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '随机昵称获取失败：$error',
              en: 'Could not get a random nickname: $error',
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _detachMarkdownPasteListener?.call();
    _draftTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _anonymousAliasController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final CreatePostState state = ref.watch(createPostControllerProvider);
    final bool isBusy =
        state.submitting || _pickingImages || _pastingMarkdownImages;
    final List<SectionItem> sections = state.sections;
    final SectionItem? selectedSection = _validSelectedSection(sections);
    final bool wide = MediaQuery.sizeOf(context).width >= 1200;

    final Widget editor = _buildEditor(context, t, isBusy, wide);
    final Widget settings = _buildSettings(
      context,
      t,
      state,
      isBusy,
      sections,
      selectedSection,
    );

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(_saveDraft());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: uiText(context, zh: '关闭', en: 'Close'),
            icon: const Icon(Icons.close_rounded),
            onPressed: state.submitting
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
          title: Text(uiText(context, zh: '发布心声', en: 'New post')),
          actions: <Widget>[
            Center(
              child: ZxButton(
                label: uiText(context, zh: '清空草稿', en: 'Clear draft'),
                variant: ZxButtonVariant.ghost,
                small: true,
                onPressed: isBusy ? null : _confirmClearDraft,
              ),
            ),
            const SizedBox(width: 6),
            Center(
              child: ZxButton(
                key: const Key('create-post-submit'),
                label: state.submitting
                    ? uiText(context, zh: '发布中', en: 'Publishing')
                    : uiText(context, zh: '发布', en: 'Publish'),
                icon: Icons.send_rounded,
                small: true,
                loading: state.submitting,
                onPressed: isBusy || state.loadingSections
                    ? null
                    : () => _trySubmit(sections),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ZxPaper(
          child: AsyncPageState(
            loading: state.loadingSections,
            loadingLabel: uiText(
              context,
              zh: '正在准备发布表单',
              en: 'Preparing the compose form',
            ),
            error: state.error,
            onRetry: () =>
                ref.read(createPostControllerProvider.notifier).loadSections(),
            child: Form(
              key: _formKey,
              child: ListView(
                key: const Key('create-post-form-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1180 : 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildStatusLine(context, t, state, isBusy),
                          const SizedBox(height: 12),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: editor),
                                const SizedBox(width: 20),
                                SizedBox(width: 340, child: settings),
                              ],
                            )
                          else ...<Widget>[
                            editor,
                            const SizedBox(height: 16),
                            settings,
                          ],
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

  /// Draft state, the validation summary, or progress while submitting.
  Widget _buildStatusLine(
    BuildContext context,
    ZxTokens t,
    CreatePostState state,
    bool isBusy,
  ) {
    if (isBusy) {
      return ZxInlineMessage(
        message: _pastingMarkdownImages
            ? uiText(context, zh: '上传粘贴图片中…', en: 'Uploading pasted images…')
            : _pickingImages
            ? uiText(context, zh: '读取图片中…', en: 'Reading images…')
            : (state.progressText ??
                  uiText(context, zh: '发布中…', en: 'Publishing…')),
      );
    }
    final List<GlobalKey> missing = _missingFields();
    if (_showErrors && missing.isNotEmpty) {
      return ZxInlineMessage(
        key: const Key('create-post-error-summary'),
        tone: ZxMessageTone.danger,
        message: uiText(
          context,
          zh: '还有 ${missing.length} 项需要填写',
          en: '${missing.length} field${missing.length == 1 ? '' : 's'} still need attention',
        ),
        actionLabel: uiText(context, zh: '点击定位', en: 'Show'),
        onAction: () => _scrollTo(missing.first),
      );
    }
    final DateTime? saved = _draftSavedAt;
    return Row(
      children: <Widget>[
        Icon(Icons.cloud_done_outlined, size: 16, color: t.text3),
        const SizedBox(width: 6),
        Text(
          saved == null
              ? uiText(
                  context,
                  zh: '草稿会在输入停顿后自动保存',
                  en: 'Drafts save when you pause typing',
                )
              : uiText(
                  context,
                  zh: '草稿已自动保存 · ${_clock(saved)}',
                  en: 'Draft saved · ${_clock(saved)}',
                ),
          style: ZxType.caption.copyWith(color: t.text3),
        ),
      ],
    );
  }

  Widget _buildEditor(
    BuildContext context,
    ZxTokens t,
    bool isBusy,
    bool wide,
  ) {
    final Locale locale = Localizations.localeOf(context);
    final Widget source = TextFormField(
      key: ValueKey<String>(
        _useMarkdown
            ? 'create-post-markdown-editor'
            : 'create-post-plain-editor',
      ),
      controller: _contentController,
      focusNode: _contentFocusNode,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      minLines: 10,
      maxLines: 22,
      // The server counts code points (Python len), not grapheme clusters.
      maxLength: _useMarkdown ? null : _plainTextMaxLength,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      inputFormatters: _useMarkdown
          ? null
          : <TextInputFormatter>[
              const CodePointLimitFormatter(_plainTextMaxLength),
            ],
      buildCounter: _useMarkdown ? null : codePointCounter(_contentController),
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
      // No monospace here: web cannot reach system fonts and bundles none,
      // so a monospace family would fall back to the serif.
      style: ZxType.body.copyWith(color: t.text),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
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
            : null,
      ),
      validator: (String? value) {
        if (value == null || value.trim().isEmpty) {
          return uiTextFor(locale, zh: '请输入正文', en: 'Please enter the body');
        }
        if (!_useMarkdown && value.runes.length > _plainTextMaxLength) {
          return uiTextFor(
            locale,
            zh: '纯文本正文最多 $_plainTextMaxLength 字',
            en: 'Plain text is limited to $_plainTextMaxLength characters',
          );
        }
        if (_useMarkdown && value.runes.length > PostLimits.markdownSource) {
          return uiTextFor(
            locale,
            zh: 'Markdown 最多 ${PostLimits.markdownSource} 字',
            en: 'Markdown is limited to ${PostLimits.markdownSource} characters',
          );
        }
        return null;
      },
    );
    final Widget preview = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _contentController,
      builder: (BuildContext context, TextEditingValue value, Widget? child) {
        final String markdown = value.text.trim();
        if (markdown.isEmpty) {
          return Text(
            uiText(
              context,
              zh: '输入 Markdown 源码后，这里会显示渲染效果。',
              en: 'Type Markdown and the rendered result appears here.',
            ),
            style: ZxType.body.copyWith(color: t.text3),
          );
        }
        return PostContentBody(
          content: '',
          contentFormat: 'markdown',
          markdownSource: markdown,
          selectable: false,
        );
      },
    );

    Widget body;
    if (!_useMarkdown) {
      body = source;
    } else if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: source),
          Container(
            width: 1,
            height: 360,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: t.line,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  uiText(context, zh: '实时预览', en: 'Live preview'),
                  style: ZxType.micro.copyWith(color: t.text3),
                ),
                const SizedBox(height: 8),
                preview,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(uiText(context, zh: '编辑', en: 'Edit')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(uiText(context, zh: '预览', en: 'Preview')),
                ),
              ],
              selected: <bool>{_showPreview},
              onSelectionChanged: (Set<bool> value) =>
                  setState(() => _showPreview = value.first),
            ),
          ),
          const SizedBox(height: 12),
          // Keep the source field mounted so validation still sees it.
          Offstage(offstage: _showPreview, child: source),
          if (_showPreview) preview,
        ],
      );
    }

    return ZxCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.tab):
                  DoNothingAndStopPropagationIntent(),
              SingleActivator(LogicalKeyboardKey.tab, shift: true):
                  DoNothingAndStopPropagationIntent(),
            },
            child: TextFormField(
              key: _titleFieldKey,
              controller: _titleController,
              maxLength: PostLimits.title,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              inputFormatters: <TextInputFormatter>[
                CodePointLimitFormatter(PostLimits.title),
              ],
              buildCounter: codePointCounter(_titleController),
              style: ZxType.titleLarge.copyWith(color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                hintText: uiText(context, zh: '标题（必填）', en: 'Title (required)'),
                hintStyle: ZxType.titleLarge.copyWith(color: t.text3),
              ),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                  ? uiTextFor(locale, zh: '请填写标题', en: 'Please enter a title')
                  : null,
            ),
          ),
          Divider(height: 20, color: t.line),
          Row(
            children: <Widget>[
              EmojiAssistantBar(controller: _contentController, compact: true),
              const Spacer(),
              Text('Markdown', style: ZxType.caption.copyWith(color: t.text2)),
              const SizedBox(width: 6),
              Switch(
                value: _useMarkdown,
                onChanged: isBusy ? null : _handleMarkdownToggle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyedSubtree(key: _contentFieldKey, child: body),
          const SizedBox(height: 16),
          _buildImages(context, t, isBusy),
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context, ZxTokens t, bool isBusy) {
    const double tile = 96;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (int i = 0; i < _pickedImages.length; i++)
          _PickedImageCard(
            image: _pickedImages[i],
            onRemove: isBusy
                ? null
                : () => setState(() => _pickedImages.removeAt(i)),
          ),
        if (_imageCount < 9)
          Material(
            color: t.bgSunk,
            borderRadius: ZxRadius.buttonAll,
            child: InkWell(
              key: const Key('create-post-add-image'),
              borderRadius: ZxRadius.buttonAll,
              onTap: isBusy ? null : _pickImages,
              child: SizedBox(
                width: tile,
                height: tile,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.add_photo_alternate_outlined, color: t.text3),
                    const SizedBox(height: 4),
                    Text(
                      '$_imageCount/9',
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(
          uiText(
            context,
            zh: '支持 jpg / png / webp / gif，最多 9 张',
            en: 'jpg / png / webp / gif, up to 9',
          ),
          style: ZxType.caption.copyWith(color: t.text3),
        ),
      ],
    );
  }

  Widget _buildSettings(
    BuildContext context,
    ZxTokens t,
    CreatePostState state,
    bool isBusy,
    List<SectionItem> sections,
    SectionItem? selectedSection,
  ) {
    final Locale locale = Localizations.localeOf(context);
    Widget label(
      String zh,
      String en, {
      bool required = false,
      String? noteZh,
      String? noteEn,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            uiText(context, zh: zh, en: en),
            style: ZxType.label.copyWith(color: t.text),
          ),
          if (required)
            Text(' *', style: ZxType.label.copyWith(color: t.danger)),
          if (noteZh != null) ...<Widget>[
            const SizedBox(width: 8),
            ZxBadge.level(uiText(context, zh: noteZh, en: noteEn!)),
          ],
        ],
      ),
    );
    final bool sectionMissing = _showErrors && selectedSection == null;
    final String? tagProblem = _showErrors ? _tagProblem() : null;

    return ZxCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KeyedSubtree(
            key: _sectionFieldKey,
            child: label('分区', 'Section', required: true),
          ),
          if (sections.isEmpty)
            const _EmptySectionCard()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final SectionItem section in sections)
                  ChoiceChip(
                    key: Key('create-post-section-${section.key}'),
                    label: Text(section.sectionName),
                    avatar: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: t.channelFor(section.sectionName),
                        shape: BoxShape.circle,
                      ),
                    ),
                    showCheckmark: false,
                    selected: selectedSection == section,
                    onSelected: isBusy
                        ? null
                        : (_) {
                            setState(() => _selectedSectionKey = section.key);
                            _scheduleDraftSave();
                          },
                  ),
              ],
            ),
          if (sectionMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                uiText(context, zh: '请选择分区', en: 'Please choose a section'),
                style: ZxType.caption.copyWith(color: t.danger),
              ),
            ),
          const SizedBox(height: 18),
          KeyedSubtree(key: _tagsFieldKey, child: label('标签', 'Tags')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in _tags)
                InputChip(
                  label: Text('#$tag'),
                  onDeleted: isBusy
                      ? null
                      : () {
                          setState(() => _tags.remove(tag));
                          _scheduleDraftSave();
                        },
                ),
              if (_tags.length < _maxTags)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(uiText(context, zh: '添加', en: 'Add')),
                  onPressed: isBusy ? null : _addTag,
                ),
            ],
          ),
          if (tagProblem != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tagProblem,
                style: ZxType.caption.copyWith(color: t.danger),
              ),
            ),
          const SizedBox(height: 18),
          label('状态', 'Status'),
          SegmentedButton<PostStatus>(
            showSelectedIcon: false,
            segments: <ButtonSegment<PostStatus>>[
              for (final PostStatus status in PostStatus.values)
                ButtonSegment<PostStatus>(
                  value: status,
                  label: Text(status.labelFor(locale)),
                ),
            ],
            selected: <PostStatus>{_status},
            onSelectionChanged: isBusy
                ? null
                : (Set<PostStatus> value) {
                    setState(() => _status = value.first);
                    _scheduleDraftSave();
                  },
          ),
          const SizedBox(height: 18),
          label('可见范围', 'Visibility'),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: false,
                label: Text(uiText(context, zh: '所有人', en: 'Everyone')),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(uiText(context, zh: '仅自己', en: 'Only me')),
              ),
            ],
            selected: <bool>{_privateOnly},
            onSelectionChanged: isBusy
                ? null
                : (Set<bool> value) {
                    setState(() => _privateOnly = value.first);
                    _scheduleDraftSave();
                  },
          ),
          const SizedBox(height: 6),
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
            style: ZxType.caption.copyWith(color: t.text3),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      uiText(context, zh: '匿名发布', en: 'Post anonymously'),
                      style: ZxType.label.copyWith(color: t.text),
                    ),
                    Text(
                      uiText(
                        context,
                        zh: '以朱印头像和匿名昵称显示',
                        en: 'Shown with the seal and an alias',
                      ),
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useAnonymousAlias,
                onChanged: isBusy
                    ? null
                    : (bool value) {
                        setState(() => _useAnonymousAlias = value);
                        _scheduleDraftSave();
                      },
              ),
            ],
          ),
          if (_useAnonymousAlias) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _anonymousAliasController,
                    builder:
                        (
                          BuildContext context,
                          TextEditingValue value,
                          Widget? child,
                        ) => ZxAvatar.anonymous(
                          name: value.text.trim().isEmpty
                              ? '匿'
                              : value.text.trim(),
                          size: 36,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _anonymousAliasController,
                    maxLength: 24,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    inputFormatters: <TextInputFormatter>[
                      CodePointLimitFormatter(24),
                    ],
                    buildCounter: codePointCounter(_anonymousAliasController),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: uiText(
                        context,
                        zh: '匿名昵称（选填）',
                        en: 'Alias (optional)',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ZxButton(
                    key: const Key('anonymous-alias-random'),
                    label: uiText(context, zh: '随机', en: 'Random'),
                    icon: Icons.casino_outlined,
                    variant: ZxButtonVariant.secondary,
                    small: true,
                    onPressed: isBusy ? null : _fillRandomAlias,
                  ),
                ),
              ],
            ),
          ],
          if (state.isLevelOneUser) ...<Widget>[
            const SizedBox(height: 18),
            label('置顶时长', 'Pin for', noteZh: '仅一级用户可见', noteEn: 'Level 1 only'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (int?, String, String) option in _pinOptions)
                  ChoiceChip(
                    label: Text(uiText(context, zh: option.$2, en: option.$3)),
                    selected: _selectedPinDurationMinutes == option.$1,
                    onSelected: isBusy
                        ? null
                        : (_) => setState(
                            () => _selectedPinDurationMinutes = option.$1,
                          ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Fields that block publishing, in page order.
  List<GlobalKey> _missingFields() {
    final CreatePostState state = ref.read(createPostControllerProvider);
    return <GlobalKey>[
      if (_titleController.text.trim().isEmpty) _titleFieldKey,
      if (_contentController.text.trim().isEmpty ||
          _contentController.text.length >
              (_useMarkdown ? PostLimits.markdownSource : _plainTextMaxLength))
        _contentFieldKey,
      if (_validSelectedSection(state.sections) == null) _sectionFieldKey,
      if (_tagProblem() != null) _tagsFieldKey,
    ];
  }

  /// The server merges the #topics in the title and body into the tags.
  String? _tagProblem() => PostLimits.tagProblem(
    _tags,
    _titleController.text.trim(),
    _contentController.text,
  );

  void _scrollTo(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: ZxMotion.standard,
        alignment: 0.1,
      );
    }
  }

  /// Validates everything at once (P2); submits only when nothing is missing.
  Future<void> _trySubmit(List<SectionItem> sections) async {
    final bool formValid = _formKey.currentState!.validate();
    final SectionItem? section = _validSelectedSection(sections);
    if (!formValid || section == null || _tagProblem() != null) {
      setState(() => _showErrors = true);
      final List<GlobalKey> missing = _missingFields();
      if (missing.isNotEmpty) _scrollTo(missing.first);
      return;
    }
    await _submit(section);
  }

  Future<void> _addTag() async {
    final String? tag = await showDialog<String>(
      context: context,
      builder: (_) => const _AddTagDialog(),
    );
    if (tag == null || tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _scheduleDraftSave();
  }

  Future<void> _confirmClearDraft() async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '清空草稿？', en: 'Clear the draft?'),
      message: uiText(
        context,
        zh: '标题、正文和已选设置都会清空。',
        en: 'Title, body and settings are all cleared.',
      ),
      confirmLabel: uiText(context, zh: '清空', en: 'Clear'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    _draftTimer?.cancel();
    await _clearDraft();
    setState(() {
      _titleController.clear();
      _contentController.clear();
      _anonymousAliasController.clear();
      _plainDraft = '';
      _markdownDraft = '';
      _tags.clear();
      _pickedImages.clear();
      _selectedSectionKey = null;
      _selectedPinDurationMinutes = null;
      _status = PostStatus.ongoing;
      _privateOnly = false;
      _useAnonymousAlias = false;
      _showErrors = false;
      _draftSavedAt = null;
    });
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(_saveDraft()),
    );
  }

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
      _selectedSectionKey = draft['sectionKey']?.toString();
      _privateOnly = draft['privateOnly'] == true;
      _useAnonymousAlias = draft['anonymous'] == true;
      _anonymousAliasController.text =
          draft['anonymousAlias']?.toString() ?? '';
      _tags
        ..clear()
        ..addAll(
          (draft['tags'] is List
                  ? draft['tags'] as List<dynamic>
                  : const <dynamic>[])
              .map((dynamic tag) => tag.toString())
              .where((String tag) => tag.isNotEmpty),
        );
      final dynamic pin = draft['pinDurationMinutes'];
      _selectedPinDurationMinutes = pin is int ? pin : null;
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
        'sectionKey': _selectedSectionKey,
        'status': _status.name,
        'privateOnly': _privateOnly,
        'anonymous': _useAnonymousAlias,
        'anonymousAlias': _anonymousAliasController.text,
        'tags': _tags,
        'pinDurationMinutes': _selectedPinDurationMinutes,
      }),
    );
    if (mounted) {
      setState(() => _draftSavedAt = DateTime.now());
    }
  }

  Future<void> _clearDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  /// The chosen section if one may still post to it, else 综合 (the
  /// server's default section).
  SectionItem? _validSelectedSection(List<SectionItem> sections) {
    for (final SectionItem section in sections) {
      if (section.key == _selectedSectionKey) return section;
    }
    return sections.where((SectionItem s) => s.isGeneral).firstOrNull;
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

      const int maxImages = 9;
      final int remaining = maxImages - _imageCount;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                zh: '最多上传 9 张图片',
                en: 'You can upload up to 9 images',
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
                zh: '最多上传 9 张图片，已自动保留前 $remaining 张。超出 ${selected.length - accepted.length} 张未选中。',
                en: 'Up to 9 images: kept the first $remaining, skipped ${selected.length - accepted.length}.',
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

  Future<void> _submit(SectionItem section) async {
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
          section: section,
          tags: List<String>.of(_tags),
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
    const int maxImages = 9;
    final int remaining =
        maxImages -
        (_pickedImages.length + _markdownImageUploadIdsByUrl.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              zh: '最多上传 9 张图片',
              en: 'You can upload up to 9 images',
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
                zh: '最多上传 9 张图片，超出 ${images.length - accepted.length} 张未插入。',
                en: 'Up to 9 images: ${images.length - accepted.length} were not inserted.',
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

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard();

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
              uiText(context, zh: '暂无可用分区', en: 'No sections available'),
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

/// Asks for one tag: letters, digits, CJK or -, up to 30, as the server's
/// inline #tag rule accepts.
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog();

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  // Letters of any script, digits, marks, '_' and '-': what Python's
  // Unicode \w (plus '-') accepts, counted in code points like the server.
  static final RegExp _allowed = RegExp(
    '^[\\p{L}\\p{N}\\p{M}_-]{1,${PostLimits.tagLength}}\$',
    unicode: true,
  );
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String tag = _controller.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!_allowed.hasMatch(tag)) {
      setState(
        () => _error = uiText(
          context,
          zh: '标签为 1–${PostLimits.tagLength} 个字，只能用文字、数字、下划线或 -',
          en: '1–${PostLimits.tagLength} letters, digits, _ or -',
        ),
      );
      return;
    }
    Navigator.of(context).pop(tag);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, zh: '添加标签', en: 'Add a tag')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PostLimits.tagLength,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        inputFormatters: <TextInputFormatter>[
          CodePointLimitFormatter(PostLimits.tagLength),
        ],
        buildCounter: codePointCounter(_controller),
        decoration: InputDecoration(prefixText: '#', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, zh: '取消', en: 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(uiText(context, zh: '添加', en: 'Add')),
        ),
      ],
    );
  }
}
