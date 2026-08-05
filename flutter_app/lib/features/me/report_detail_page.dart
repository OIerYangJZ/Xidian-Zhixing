import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
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
    final String targetLabel = _report.targetTitle.trim().isNotEmpty
        ? '${_report.target}（${_report.targetTitle}）'
        : _report.target;
    final String statusText = _report.result.trim().isNotEmpty
        ? '${_report.status} · ${_report.result}'
        : _report.status;

    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '举报详情', en: 'Report details')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: _loading
              ? AppStatePanel(
                  icon: Icons.fact_check_outlined,
                  title: uiText(
                    context,
                    zh: '正在加载举报详情',
                    en: 'Loading report details',
                  ),
                  message: uiText(
                    context,
                    zh: '正在获取最新处理结果。',
                    en: 'Fetching the latest moderation result.',
                  ),
                )
              : ListView(
                  padding: AppLayout.pagePadding(context),
                  children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppInlineMessage(
                          title: uiText(
                            context,
                            zh: '最新状态加载失败',
                            en: 'Could not refresh status',
                          ),
                          message: _error!,
                          tone: AppMessageTone.error,
                          action: TextButton(
                            onPressed: _loadDetail,
                            child: Text(
                              uiText(context, zh: '重试', en: 'Retry'),
                            ),
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              uiText(
                                context,
                                zh: '举报单号：${_report.id}',
                                en: 'Report ID: ${_report.id}',
                              ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              uiText(
                                context,
                                zh: '举报对象：$targetLabel',
                                en: 'Target: $targetLabel',
                              ),
                            ),
                            Text(
                              uiText(
                                context,
                                zh: '举报原因：${_report.reason}',
                                en: 'Reason: ${_report.reason}',
                              ),
                            ),
                            if (_report.description.trim().isNotEmpty)
                              Text(
                                uiText(
                                  context,
                                  zh: '补充说明：${_report.description}',
                                  en: 'Details: ${_report.description}',
                                ),
                              ),
                            Text(
                              uiText(
                                context,
                                zh: '处理状态：$statusText',
                                en: 'Status: $statusText',
                              ),
                            ),
                            if (_report.createdAt.trim().isNotEmpty)
                              Text(
                                uiText(
                                  context,
                                  zh: '提交时间：${_report.createdAt}',
                                  en: 'Submitted: ${_report.createdAt}',
                                ),
                              ),
                            if (_report.handledAt.trim().isNotEmpty)
                              Text(
                                uiText(
                                  context,
                                  zh: '处理时间：${_report.handledAt}',
                                  en: 'Handled: ${_report.handledAt}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_canOpenTarget())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.icon(
                          onPressed: _openingTarget ? null : _openTargetPost,
                          icon: _openingTarget
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_outlined),
                          label: Text(
                            _openingTarget
                                ? uiText(context, zh: '打开中...', en: 'Opening...')
                                : uiText(
                                    context,
                                    zh: '查看被举报帖子',
                                    en: 'View reported post',
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            uiTextGlobal(
              zh: '打开帖子失败：$error',
              en: 'Could not open the post: $error',
            ),
          ),
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
