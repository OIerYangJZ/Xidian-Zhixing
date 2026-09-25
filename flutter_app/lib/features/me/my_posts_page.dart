import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/post_card.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<PostItem> _posts = const <PostItem>[];
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的帖子', en: 'My posts')),
      ),
      body: ZxPaper(
        child: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ZxInlineMessage(
                                  message: _error!,
                                  tone: ZxMessageTone.danger,
                                  actionLabel: uiText(
                                    context,
                                    zh: '重试',
                                    en: 'Retry',
                                  ),
                                  onAction: _actionBusy ? null : _loadData,
                                ),
                              ),
                            if (_posts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                                child: Text(
                                  uiText(
                                    context,
                                    zh: '共 ${_posts.length} 篇，包括匿名、仅自己可见和审核中的帖子',
                                    en: '${_posts.length} posts, including anonymous, private and in-review ones',
                                  ),
                                  style: ZxType.caption.copyWith(
                                    color: t.text3,
                                  ),
                                ),
                              ),
                            for (final PostItem post in _posts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _MyPostEntry(
                                  post: post,
                                  busy: _actionBusy,
                                  onOpen: () => _open(post),
                                  onStatus: (PostStatus status) =>
                                      _updateStatus(post, status),
                                  onPin: () => _handlePin(post),
                                  onDelete: () => _delete(post),
                                ),
                              ),
                            if (_posts.isEmpty && _error == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 60),
                                child: ZxStatePanel(
                                  key: const Key('my-posts-empty-state'),
                                  icon: Icons.post_add_outlined,
                                  title: uiText(
                                    context,
                                    zh: '你还没有发布帖子',
                                    en: 'You have not published any posts yet',
                                  ),
                                  message: uiText(
                                    context,
                                    zh: '回到帖子流，使用发布按钮分享第一条内容。',
                                    en: 'Go back to the feed and use the compose button to share your first post.',
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
    );
  }

  Future<void> _open(PostItem post) async {
    final PostItem? updated = await openPostDetailPage(context, post: post);
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _posts = _posts
          .map((PostItem item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<PostItem> posts = await AppRepositories.posts.fetchMyPosts();
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = posts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Load failed: $error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(PostItem post, PostStatus next) async {
    if (next == post.status) return;
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.updateMyPostStatus(
        postId: post.id,
        status: next,
      );
      if (!mounted) {
        return;
      }
      _toast(
        uiTextGlobal(
          zh: '帖子状态已更新为 ${next.labelFor(const Locale('zh', 'CN'))}',
          en: 'Post status updated to ${next.labelFor(const Locale('en'))}',
        ),
      );
      await _loadData();
    } catch (error) {
      _toast(uiTextGlobal(zh: '更新失败：$error', en: 'Update failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _delete(PostItem post) async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '删除这条帖子？', en: 'Delete this post?'),
      message: uiText(
        context,
        zh: '删除后无法恢复，相关内容将不再展示。',
        en: 'This cannot be undone. The post will no longer be visible.',
      ),
      confirmLabel: uiText(context, zh: '确认删除', en: 'Delete'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.deleteMyPost(post.id);
      if (!mounted) {
        return;
      }
      _toast(uiTextGlobal(zh: '帖子已删除', en: 'Post deleted'));
      await _loadData();
    } catch (error) {
      _toast(uiTextGlobal(zh: '删除失败：$error', en: 'Delete failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _handlePin(PostItem post) async {
    final _PinActionInput? input = await _showPinDialog(direct: false);
    if (input == null) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      final result = await AppRepositories.posts.submitPinRequest(
        postId: post.id,
        durationMinutes: input.durationMinutes,
        reason: input.reason,
      );
      if (!mounted) {
        return;
      }
      if (result.post != null) {
        setState(() {
          _posts = _posts
              .map((PostItem item) => item.id == post.id ? result.post! : item)
              .toList(growable: false);
        });
      }
      _toast(
        result.isDirect
            ? uiTextGlobal(zh: '帖子已置顶', en: 'Post pinned')
            : uiTextGlobal(zh: '置顶申请已提交', en: 'Pin request submitted'),
      );
    } catch (error) {
      _toast(uiTextGlobal(zh: '操作失败：$error', en: 'Action failed: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<_PinActionInput?> _showPinDialog({required bool direct}) {
    return showDialog<_PinActionInput>(
      context: context,
      builder: (_) => _PinDialog(direct: direct),
    );
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    zxShowToast(context, message);
  }
}

class _PinActionInput {
  const _PinActionInput({required this.durationMinutes, required this.reason});

  final int durationMinutes;
  final String reason;
}

/// One of my posts with its owner actions: status, pin and delete.
class _MyPostEntry extends StatelessWidget {
  const _MyPostEntry({
    required this.post,
    required this.busy,
    required this.onOpen,
    required this.onStatus,
    required this.onPin,
    required this.onDelete,
  });

  final PostItem post;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<PostStatus> onStatus;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PostCard(post: post, onTap: onOpen),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            PopupMenuButton<PostStatus>(
              key: Key('my-post-status-${post.id}'),
              enabled: !busy,
              tooltip: uiText(context, zh: '更新状态', en: 'Update status'),
              onSelected: onStatus,
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<PostStatus>>[
                    for (final PostStatus status in PostStatus.values)
                      CheckedPopupMenuItem<PostStatus>(
                        value: status,
                        checked: status == post.status,
                        child: Text(status.labelFor(locale)),
                      ),
                  ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: ZxRadius.buttonAll,
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      uiText(
                        context,
                        zh: '状态：${post.status.labelFor(locale)}',
                        en: 'Status: ${post.status.labelFor(locale)}',
                      ),
                      style: ZxType.caption.copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more_rounded, size: 16, color: t.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ZxButton(
              key: Key('my-post-pin-${post.id}'),
              label: post.isPinned
                  ? uiText(context, zh: '重新置顶', en: 'Re-pin')
                  : uiText(context, zh: '申请置顶', en: 'Request pin'),
              icon: Icons.push_pin_outlined,
              variant: ZxButtonVariant.ghost,
              small: true,
              onPressed: busy ? null : onPin,
            ),
            const Spacer(),
            ZxButton(
              key: Key('my-post-delete-${post.id}'),
              label: uiText(context, zh: '删除', en: 'Delete'),
              icon: Icons.delete_outline_rounded,
              variant: ZxButtonVariant.ghost,
              small: true,
              onPressed: busy ? null : onDelete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: t.line),
      ],
    );
  }
}

/// Owns its controller, so it lives until the dialog's exit animation ends.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.direct});

  final bool direct;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  static const List<(int, String, String)> _durations = <(int, String, String)>[
    (30, '30 分钟', '30 min'),
    (60, '1 小时', '1 hour'),
    (120, '2 小时', '2 hours'),
    (180, '3 小时', '3 hours'),
    (1440, '1 天', '1 day'),
    (4320, '3 天', '3 days'),
  ];

  final TextEditingController _reason = TextEditingController();
  int _duration = 30;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bool direct = widget.direct;
    return AlertDialog(
      title: Text(
        direct
            ? uiText(context, zh: '选择置顶时长', en: 'Choose a pin duration')
            : uiText(context, zh: '申请帖子置顶', en: 'Request a pinned post'),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              uiText(context, zh: '置顶时长', en: 'Pin duration'),
              style: ZxType.caption.copyWith(
                color: t.text2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (int minutes, String zh, String en) in _durations)
                  ChoiceChip(
                    showCheckmark: false,
                    selected: _duration == minutes,
                    label: Text(uiText(context, zh: zh, en: en)),
                    onSelected: (_) => setState(() => _duration = minutes),
                  ),
              ],
            ),
            if (!direct) ...<Widget>[
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    zh: '申请说明（可选）',
                    en: 'Reason (optional)',
                  ),
                  hintText: uiText(
                    context,
                    zh: '例如：活动通知、紧急求助、时效性较强等',
                    en: 'e.g. event announcement, urgent request, time-sensitive',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        ZxButton(
          label: uiText(context, zh: '取消', en: 'Cancel'),
          variant: ZxButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ZxButton(
          label: direct
              ? uiText(context, zh: '确认置顶', en: 'Pin post')
              : uiText(context, zh: '提交申请', en: 'Submit request'),
          onPressed: () => Navigator.of(context).pop(
            _PinActionInput(
              durationMinutes: _duration,
              reason: _reason.text.trim(),
            ),
          ),
        ),
      ],
    );
  }
}
