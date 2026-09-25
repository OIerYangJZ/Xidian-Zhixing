import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../design_system/design_system.dart';
import '../../models/post_item.dart';
import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';
import '../../core/l10n/ui_text.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({super.key, required this.report});

  final ReportItem report;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late ReportItem _report = widget.report;
  bool _loading = true;
  bool _openingTarget = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: ZxType.caption.copyWith(fontSize: 13, color: t.text3),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: ZxType.body.copyWith(color: t.text),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '举报详情', en: 'Report details')),
      ),
      body: ZxPaper(
        child: _loading && _report.id.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
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
                                onAction: _loadDetail,
                              ),
                            ),
                          ZxCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        _report.targetLabelFor(locale),
                                        style: ZxType.title.copyWith(
                                          color: t.text,
                                        ),
                                      ),
                                    ),
                                    if (_report.isPending)
                                      ZxBadge.pendingReview(
                                        _report.statusLabelFor(locale),
                                      )
                                    else
                                      ZxBadge.resolved(
                                        _report.statusLabelFor(locale),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(height: 1, color: t.line),
                                const SizedBox(height: 6),
                                row(
                                  uiText(context, zh: '举报原因', en: 'Reason'),
                                  _report.reason,
                                ),
                                if (_report.description.trim().isNotEmpty)
                                  row(
                                    uiText(context, zh: '补充说明', en: 'Details'),
                                    _report.description,
                                  ),
                                if (_report.result.trim().isNotEmpty)
                                  row(
                                    uiText(context, zh: '处理结果', en: 'Outcome'),
                                    _report.result,
                                  ),
                                if (_report.createdAt.trim().isNotEmpty)
                                  row(
                                    uiText(
                                      context,
                                      zh: '提交时间',
                                      en: 'Submitted',
                                    ),
                                    _report.createdAt,
                                  ),
                                if (_report.handledAt.trim().isNotEmpty)
                                  row(
                                    uiText(context, zh: '处理时间', en: 'Handled'),
                                    _report.handledAt,
                                  ),
                                row(
                                  uiText(context, zh: '举报单号', en: 'Report ID'),
                                  _report.id,
                                ),
                              ],
                            ),
                          ),
                          if (_canOpenTarget()) ...<Widget>[
                            const SizedBox(height: 14),
                            ZxButton(
                              key: const Key('report-open-target'),
                              label: uiText(
                                context,
                                zh: '查看被举报帖子',
                                en: 'View reported post',
                              ),
                              icon: Icons.open_in_new_rounded,
                              variant: ZxButtonVariant.secondary,
                              expand: true,
                              loading: _openingTarget,
                              onPressed: _openingTarget
                                  ? null
                                  : _openTargetPost,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ReportItem detail = await AppRepositories.users.fetchMyReportDetail(
        widget.report.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = detail;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = uiTextGlobal(
          zh: '加载举报详情失败：$error',
          en: 'Could not load report details: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _canOpenTarget() {
    final String targetType = _report.targetType.trim().toLowerCase();
    final String targetId = _report.targetId.trim();
    if (targetType != 'post') {
      return false;
    }
    return targetId.isNotEmpty && targetId != 'unknown';
  }

  Future<void> _openTargetPost() async {
    final String postId = _report.targetId.trim();
    if (postId.isEmpty) {
      return;
    }

    setState(() {
      _openingTarget = true;
    });
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) {
        return;
      }
      await openPostDetailPage(context, post: post);
    } catch (error) {
      if (!mounted) {
        return;
      }
      zxShowToast(
        context,
        uiTextGlobal(
          zh: '打开帖子失败：$error',
          en: 'Could not open the post: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingTarget = false;
        });
      }
    }
  }
}
