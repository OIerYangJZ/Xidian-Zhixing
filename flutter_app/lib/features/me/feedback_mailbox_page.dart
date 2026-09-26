import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/code_point_limit.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/feedback_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/post_card.dart' show relativeTime;

/// 信箱 (as in the mini program's pages/profile/feedback): write to 西电知行
/// — a category, the content and an optional contact — then the records
/// with each one's status and the school's reply. Shared by web and Android.
class FeedbackMailboxPage extends StatefulWidget {
  const FeedbackMailboxPage({super.key});

  @override
  State<FeedbackMailboxPage> createState() => _FeedbackMailboxPageState();
}

class _FeedbackMailboxPageState extends State<FeedbackMailboxPage> {
  final TextEditingController _content = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  String _category = FeedbackItem.categories.first;
  bool _submitting = false;

  List<FeedbackItem> _records = const <FeedbackItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<FeedbackItem> records = await AppRepositories.users
          .fetchMyFeedback();
      if (!mounted) return;
      setState(() => _records = records);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = uiTextGlobal(
          zh: '信箱记录加载失败：$error',
          en: 'Could not load your messages: $error',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final String content = _content.text.trim();
    setState(() => _submitting = true);
    try {
      await AppRepositories.users.submitFeedback(
        category: _category,
        content: content,
        contact: _contact.text.trim(),
      );
      if (!mounted) return;
      _content.clear();
      _contact.clear();
      zxShowToast(
        context,
        uiText(
          context,
          zh: '已提交，回复会出现在记录里',
          en: 'Sent. The reply will appear below.',
        ),
      );
      await _load();
    } catch (error) {
      // e.g. 429 提交反馈过于频繁
      if (mounted) {
        zxShowToast(
          context,
          uiTextGlobal(zh: '提交失败：$error', en: 'Could not send: $error'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '信箱', en: 'Mailbox')),
      ),
      body: ZxPaper(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _sectionTitle(
                        t,
                        uiText(context, zh: '写给西电知行信箱', en: 'Write to 西电知行'),
                      ),
                      _form(t),
                      const SizedBox(height: 12),
                      ZxButton(
                        key: const Key('feedback-submit'),
                        label: _submitting
                            ? uiText(context, zh: '提交中…', en: 'Sending…')
                            : uiText(context, zh: '提交', en: 'Send'),
                        loading: _submitting,
                        expand: true,
                        onPressed: _submitting || _content.text.trim().isEmpty
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(
                        t,
                        uiText(context, zh: '我的信箱记录', en: 'My messages'),
                      ),
                      // A failed refresh keeps the records it had, but says so.
                      if (_records.isNotEmpty && _error != null) ...<Widget>[
                        ZxInlineMessage(
                          tone: ZxMessageTone.danger,
                          message: _error!,
                          actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                          onAction: _load,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _records.isEmpty ? _recordsState(t) : _recordList(t),
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

  Widget _sectionTitle(ZxTokens t, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: ZxType.caption.copyWith(
        color: t.text3,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _form(ZxTokens t) {
    return ZxCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            uiText(context, zh: '类型', en: 'Type'),
            style: ZxType.label.copyWith(color: t.text),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String category in FeedbackItem.categories)
                ChoiceChip(
                  key: Key('feedback-category-$category'),
                  showCheckmark: false,
                  selected: _category == category,
                  label: Text(category),
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            uiText(context, zh: '内容', en: 'Message'),
            style: ZxType.label.copyWith(color: t.text),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('feedback-content'),
            controller: _content,
            minLines: 4,
            maxLines: 8,
            maxLength: FeedbackItem.maxContentLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            inputFormatters: <TextInputFormatter>[
              CodePointLimitFormatter(FeedbackItem.maxContentLength),
            ],
            buildCounter: codePointCounter(_content),
            decoration: InputDecoration(
              hintText: uiText(
                context,
                zh: '具体说说遇到的问题或建议',
                en: 'Tell us what happened or what you suggest',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uiText(context, zh: '联系方式 · 可选', en: 'Contact · optional'),
            style: ZxType.label.copyWith(color: t.text),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('feedback-contact'),
            controller: _contact,
            maxLength: FeedbackItem.maxContactLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            inputFormatters: <TextInputFormatter>[
              CodePointLimitFormatter(FeedbackItem.maxContactLength),
            ],
            buildCounter: codePointCounter(_contact),
            decoration: InputDecoration(
              hintText: uiText(
                context,
                zh: '邮箱或微信，方便回复你',
                en: 'Email or WeChat, so we can reply',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsState(ZxTokens t) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ZxInlineMessage(
        tone: ZxMessageTone.danger,
        message: _error!,
        actionLabel: uiText(context, zh: '重试', en: 'Retry'),
        onAction: _load,
      );
    }
    return Padding(
      key: const Key('feedback-records-empty'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          uiText(context, zh: '还没有提交记录', en: 'Nothing sent yet'),
          style: ZxType.body.copyWith(color: t.text3),
        ),
      ),
    );
  }

  Widget _recordList(ZxTokens t) {
    return Column(
      children: <Widget>[
        for (final FeedbackItem item in _records)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ZxCard(
              key: Key('feedback-record-${item.id}'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.category,
                          style: ZxType.label.copyWith(color: t.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusBadge(item),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.content,
                    style: ZxType.body.copyWith(color: t.text2),
                  ),
                  if (item.schoolReply.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.bgSunk,
                        borderRadius: ZxRadius.buttonAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            uiText(context, zh: '回复', en: 'Reply'),
                            style: ZxType.micro.copyWith(color: t.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.schoolReply,
                            style: ZxType.body.copyWith(color: t.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _time(item.createdAt),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusBadge(FeedbackItem item) => switch (item.status) {
    'resolved' => ZxBadge.resolved(uiText(context, zh: '已回复', en: 'Replied')),
    'closed' => ZxBadge.closed(uiText(context, zh: '已关闭', en: 'Closed')),
    _ => ZxBadge.pendingReview(uiText(context, zh: '待处理', en: 'Pending')),
  };

  String _time(String createdAt) {
    final DateTime? created = DateTime.tryParse(createdAt);
    return created == null
        ? createdAt
        : relativeTime(context, created.toLocal());
  }
}
