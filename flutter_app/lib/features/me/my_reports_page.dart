import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/report_item.dart';
import '../../repositories/app_repositories.dart';
import 'report_detail_page.dart';

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
      appBar: AppBar(title: const Text('我的举报')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.readingMaxWidth,
          ),
          child: _loading
              ? const AppStatePanel(
                  icon: Icons.flag_outlined,
                  title: '正在加载举报记录',
                  message: '正在同步处理状态和管理员反馈。',
                )
              : _error != null && _items.isEmpty
              ? AppStatePanel(
                  icon: Icons.cloud_off_outlined,
                  title: '举报记录加载失败',
                  message: _error!,
                  action: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新加载'),
                  ),
                )
              : _items.isEmpty
              ? const AppStatePanel(
                  key: Key('reports-empty-state'),
                  icon: Icons.flag_outlined,
                  title: '暂无举报记录',
                  message: '你提交的举报与处理结果会出现在这里。',
                )
              : ListView.separated(
                  itemCount: _items.length,
                  padding: AppLayout.pagePadding(context),
                  itemBuilder: (BuildContext context, int index) {
                    final ReportItem row = _items[index];
                    return Card(
                      child: ListTile(
                        title: Text('${row.target} · ${row.reason}'),
                        subtitle: Text(
                          row.result.trim().isNotEmpty
                              ? '处理状态：${row.status} · ${row.result}'
                              : '处理状态：${row.status}',
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
        _error = '加载失败：$error';
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
