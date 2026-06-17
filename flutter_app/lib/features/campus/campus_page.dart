import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/shared_colors.dart';
import '../../models/campus_models.dart';
import 'campus_auth_center_page.dart';
import 'campus_service_detail_page.dart';

class CampusPage extends ConsumerStatefulWidget {
  const CampusPage({super.key});

  @override
  ConsumerState<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends ConsumerState<CampusPage> {
  bool _loading = true;
  String? _error;
  List<CampusService> _services = const <CampusService>[];
  CampusTodaySchedules _today = const CampusTodaySchedules(
    date: '',
    items: <CampusScheduleItem>[],
  );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(campusRepositoryProvider);
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.fetchServices(),
        repository.fetchTodaySchedules(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _services = (results[0] as List<CampusService>)
            .where((CampusService item) => item.hasBusinessAction)
            .toList();
        _today = results[1] as CampusTodaySchedules;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final Map<String, List<CampusService>> groups = _groupServices(_services);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: <Widget>[
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _load),
          _IdsCard(onTap: _openAuthCenter),
          const SizedBox(height: 14),
          _TodayCard(today: _today, onTap: _openScheduleSource),
          const SizedBox(height: 18),
          for (final MapEntry<String, List<CampusService>> entry
              in groups.entries) ...<Widget>[
            _SectionTitle(entry.key),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 900
                    ? 6
                    : constraints.maxWidth >= 640
                        ? 4
                        : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.08,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CampusService service = entry.value[index];
                    return _ServiceTile(
                      service: service,
                      onTap: () => _openService(service),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Map<String, List<CampusService>> _groupServices(List<CampusService> services) {
    final Map<String, List<CampusService>> groups = <String, List<CampusService>>{};
    for (final CampusService service in services) {
      final String name = service.groupName.trim().isEmpty ? '校园服务' : service.groupName;
      groups.putIfAbsent(name, () => <CampusService>[]).add(service);
    }
    return groups;
  }

  void _openAuthCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CampusAuthCenterPage()),
    );
  }

  void _openScheduleSource(CampusScheduleItem item) {
    final String slug = switch (item.source) {
      'examSchedules' => 'exam',
      'experimentSchedules' => 'experiment',
      _ => 'classtable',
    };
    final CampusService? service = _services
        .where((CampusService item) => item.slug == slug)
        .cast<CampusService?>()
        .firstOrNull;
    if (service != null) {
      _openService(service);
    }
  }

  Future<void> _openService(CampusService service) async {
    final CampusAction? action =
        service.actions.where((CampusAction item) => item.type != 'notice').firstOrNull;
    if (service.slug == 'map' ||
        service.slug == 'campus-map' ||
        action?.type == 'map') {
      await _openCampusMap();
      return;
    }
    if ((service.groupId == 'quick' || service.kind == 'external') &&
        action?.type == 'external' &&
        (action?.url ?? '').trim().isNotEmpty) {
      await launchUrl(Uri.parse(action!.url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CampusServiceDetailPage(serviceId: service.id),
      ),
    );
  }

  Future<void> _openCampusMap() async {
    await launchUrl(
      Uri.parse('https://gis.xidian.edu.cn/#/home?campus=21047'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _IdsCard extends StatelessWidget {
  const _IdsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SharedColors.divider),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.key_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '西电统一认证',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text('管理统一认证、水电、物理实验等校园系统登录'),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.onTap,
  });

  final CampusTodaySchedules today;
  final ValueChanged<CampusScheduleItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SharedColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '今日日程',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                today.date,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (today.items.isEmpty)
            Text(
              '今天没有课表、考试或实验安排',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            ...today.items.map(
              (CampusScheduleItem item) => _TodayRow(
                item: item,
                onTap: () => onTap(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.item,
    required this.onTap,
  });

  final CampusScheduleItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(
                item.timeRange,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.sourceLabel} · ${item.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.56),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (item.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '进行中',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onTap,
  });

  final CampusService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SharedColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _iconForService(service),
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForService(CampusService service) {
    final String text = '${service.slug} ${service.iconKey} ${service.name}';
    if (text.contains('map') || text.contains('地图')) return Icons.map_outlined;
    if (text.contains('exam') || text.contains('考试')) return Icons.assignment_outlined;
    if (text.contains('class') || text.contains('课表')) return Icons.calendar_month_outlined;
    if (text.contains('library') || text.contains('图书')) return Icons.local_library_outlined;
    if (text.contains('water') || text.contains('水')) return Icons.water_drop_outlined;
    if (text.contains('实验')) return Icons.science_outlined;
    return Icons.apps_rounded;
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
