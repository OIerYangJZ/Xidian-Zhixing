import 'package:flutter/material.dart';
import '../common/feature_section.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的举报', en: 'My reports')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? AppStatePanel(
                  icon: Icons.flag_outlined,
                  title: uiText(
                    context,
                    zh: '正在加载举报记录',
                    en: 'Loading your reports',
                  ),
                  message: uiText(
                    context,
                    zh: '正在同步处理状态和管理员反馈。',
                    en: 'Syncing statuses and moderator feedback.',
                  ),
                )
              : _error != null && _items.isEmpty
              ? AppStatePanel(
                  icon: Icons.cloud_off_outlined,
                  title: uiText(
                    context,
                    zh: '举报记录加载失败',
                    en: 'Could not load your reports',
                  ),
                  message: _error!,
                  action: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(uiText(context, zh: '重新加载', en: 'Reload')),
                  ),
                )
              : _items.isEmpty
              ? AppStatePanel(
                  key: const Key('reports-empty-state'),
                  icon: Icons.flag_outlined,
                  title: uiText(context, zh: '暂无举报记录', en: 'No reports yet'),
                  message: uiText(
                    context,
                    zh: '你提交的举报与处理结果会出现在这里。',
                    en: 'Reports you submit and their outcomes appear here.',
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  padding: AppLayout.pagePadding(context),
                  itemBuilder: (BuildContext context, int index) {
                    final ReportItem row = _items[index];
                    return FeatureSection(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text('${row.target} · ${row.reason}'),
                        subtitle: Text(
                          row.result.trim().isNotEmpty
                              ? uiText(
                                  context,
                                  zh: '处理状态：${row.status} · ${row.result}',
                                  en: 'Status: ${row.status} · ${row.result}',
                                )
                              : uiText(
                                  context,
                                  zh: '处理状态：${row.status}',
                                  en: 'Status: ${row.status}',
                                ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReportDetailPage(report: row),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                ),
        ),
      ),
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
