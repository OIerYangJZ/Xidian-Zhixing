import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';
import 'report_detail_page.dart';
import '../../core/l10n/ui_text.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<ReportItem> _items = const <ReportItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    Widget body;
    if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = ZxStatePanel(
        icon: Icons.cloud_off_outlined,
        error: true,
        title: uiText(
          context,
          zh: '举报记录加载失败',
          en: 'Could not load your reports',
        ),
        message: _error!,
        actionLabel: uiText(context, zh: '重新加载', en: 'Reload'),
        onAction: _load,
      );
    } else if (_items.isEmpty) {
      body = ZxStatePanel(
        key: const Key('reports-empty-state'),
        icon: Icons.flag_outlined,
        title: uiText(context, zh: '暂无举报记录', en: 'No reports yet'),
        message: uiText(
          context,
          zh: '你提交的举报与处理结果会出现在这里。',
          en: 'Reports you submit and their outcomes appear here.',
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ZxCard(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < _items.length; i++) ...<Widget>[
                        if (i > 0) Divider(height: 1, color: t.line),
                        ZxListItem(
                          key: Key('report-${_items[i].id}'),
                          icon: Icons.flag_outlined,
                          iconColor: _items[i].isPending
                              ? t.warning
                              : t.success,
                          title:
                              '${_items[i].targetLabelFor(locale)} · ${_items[i].reason}',
                          subtitle: <String>[
                            if (_items[i].result.trim().isNotEmpty)
                              _items[i].result.trim(),
                            if (_items[i].createdAt.trim().isNotEmpty)
                              _items[i].createdAt.trim(),
                          ].join(' · '),
                          trailing: _items[i].isPending
                              ? ZxBadge.pendingReview(
                                  _items[i].statusLabelFor(locale),
                                )
                              : ZxBadge.resolved(
                                  _items[i].statusLabelFor(locale),
                                ),
                          showChevron: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReportDetailPage(report: _items[i]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的举报', en: 'My reports')),
      ),
      body: ZxPaper(child: body),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<ReportItem> items = await AppRepositories.users
          .fetchMyReports();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
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
}
