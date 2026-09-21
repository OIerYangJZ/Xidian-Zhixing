import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/campus_text.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/campus_models.dart';
import 'campus_service_detail_page.dart';

class CampusPage extends ConsumerStatefulWidget {
  const CampusPage({super.key});

  @override
  ConsumerState<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends ConsumerState<CampusPage> {
  bool _loading = true;
  String _query = '';
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
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Could not load: $error');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final Map<String, List<CampusService>> groups = _groupServices(
      _services.where((CampusService service) {
        final String searchable = <String>[
          service.name,
          service.description,
          service.slug,
          localizedCampusServiceName(
            const Locale('en'),
            slug: service.slug,
            name: service.name,
          ),
          localizedCampusServiceName(
            const Locale('zh', 'CN'),
            slug: service.slug,
            name: service.name,
          ),
        ].join(' ').toLowerCase();
        return searchable.contains(_query.trim().toLowerCase());
      }).toList(),
    );
    return AppPageFrame(
      maxWidth: 720,
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: <Widget>[
            if (_error != null) _ErrorBanner(message: _error!, onRetry: _load),
            _TodayCard(today: _today, onTap: _openScheduleSource),
            const SizedBox(height: 24),
            TextField(
              decoration: InputDecoration(
                hintText: uiText(
                  context,
                  zh: '搜索校园服务',
                  en: 'Search campus services',
                ),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: 24),
            _ServicesGrid(groups: groups, onOpen: _openService),
            if (groups.isEmpty && _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  uiText(
                    context,
                    zh: '没有匹配的校园服务',
                    en: 'No matching campus services',
                  ),
                ),
              ),
            const Divider(height: 32),
            const _OfflineDinoCard(),
          ],
        ),
      ),
    );
  }

  Map<String, List<CampusService>> _groupServices(
    List<CampusService> services,
  ) {
    final Map<String, List<CampusService>> groups =
        <String, List<CampusService>>{};
    for (final CampusService service in services) {
      final String name = service.groupName.trim().isEmpty
          ? '校园服务'
          : service.groupName;
      groups.putIfAbsent(name, () => <CampusService>[]).add(service);
    }
    return groups;
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
    final CampusAction? action = service.actions
        .where((CampusAction item) => item.type != 'notice')
        .firstOrNull;
    if (service.slug == 'map' ||
        service.slug == 'campus-map' ||
        action?.type == 'map') {
      await _openCampusMap();
      return;
    }
    if ((service.groupId == 'quick' || service.kind == 'external') &&
        action?.type == 'external' &&
        (action?.url ?? '').trim().isNotEmpty) {
      // Server-supplied url: only plain web schemes may reach the system
      // launcher, and Uri.parse throws on malformed input.
      final String target = action!.url.trim();
      if (AppConfig.isWebUrl(target)) {
        await launchUrl(
          Uri.parse(target),
          mode: LaunchMode.externalApplication,
        );
      }
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

class _OfflineDinoCard extends StatefulWidget {
  const _OfflineDinoCard();

  @override
  State<_OfflineDinoCard> createState() => _OfflineDinoCardState();
}

class _OfflineDinoCardState extends State<_OfflineDinoCard> {
  int _score = 0;
  bool _jumping = false;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Semantics(
      button: true,
      label: '离线小游戏',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: () => setState(() {
          _score += 1;
          _jumping = !_jumping;
        }),
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            height: 86,
            child: Stack(
              children: <Widget>[
                Text(
                  '离线小游戏 · Dino',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Align(
                  alignment: Alignment(-0.55, _jumping ? -0.25 : 0.55),
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 30,
                    color: colors.primary,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '点击跳跃  $_score',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.groups, required this.onOpen});

  final Map<String, List<CampusService>> groups;
  final ValueChanged<CampusService> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionHeader(
          title: uiText(context, zh: '校园服务', en: 'Campus services'),
          subtitle: uiText(
            context,
            zh: '课表、考试、实验与常用校园入口',
            en: 'Schedules, exams, labs and the entrances you use most',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final MapEntry<String, List<CampusService>> entry
            in groups.entries) ...<Widget>[
          AppSectionTitle(
            title: localizedCampusGroup(
              Localizations.localeOf(context),
              entry.key,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final CampusService service in entry.value)
            _ServiceTile(service: service, onTap: () => onOpen(service)),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.onTap});

  final CampusTodaySchedules today;
  final ValueChanged<CampusScheduleItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: EditorialColors.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  uiText(context, zh: '今日日程', en: 'Today'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                today.date,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (today.items.isEmpty)
            Text(
              uiText(
                context,
                zh: '今天没有课表、考试或实验安排',
                en: 'No classes, exams or labs scheduled today',
              ),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            ...today.items.map(
              (CampusScheduleItem item) =>
                  _TodayRow(item: item, onTap: () => onTap(item)),
            ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.item, required this.onTap});

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
                style: const TextStyle(fontWeight: FontWeight.w600),
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${localizedScheduleSource(Localizations.localeOf(context), item.sourceLabel)}'
                    ' · ${item.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.56),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Text(
                  uiText(context, zh: '进行中', en: 'Now'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final CampusService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final String description = localizedCampusServiceDescription(
      locale,
      slug: service.slug,
      description: service.description,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Icon(_iconForService(service)),
        title: Text(
          localizedCampusServiceName(
            locale,
            slug: service.slug,
            name: service.name,
          ),
        ),
        subtitle: description.trim().isEmpty ? null : Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_statusLabel(context, service) case final String label)
              AppStatusTag(label: label, outlined: true),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForService(CampusService service) {
    final String text = '${service.slug} ${service.iconKey} ${service.name}';
    if (text.contains('map') || text.contains('地图')) return Icons.map_outlined;
    if (text.contains('exam') || text.contains('考试'))
      return Icons.assignment_outlined;
    if (text.contains('class') || text.contains('课表'))
      return Icons.calendar_month_outlined;
    if (text.contains('library') || text.contains('图书'))
      return Icons.local_library_outlined;
    if (text.contains('water') || text.contains('水'))
      return Icons.water_drop_outlined;
    if (text.contains('实验')) return Icons.science_outlined;
    return Icons.apps_rounded;
  }

  String? _statusLabel(BuildContext context, CampusService service) {
    final String authType = service.authType.trim();
    if (authType.isEmpty || service.authReady) {
      return uiText(context, zh: '可使用', en: 'Ready');
    }
    if (authType == 'public') {
      return uiText(context, zh: '公开入口', en: 'Open');
    }
    // Unified identity services inherit the current sign-in session. They do
    // not expose a second credential flow or a repeated authentication warning.
    if (authType == 'ids') {
      return null;
    }
    return uiText(context, zh: '需单独登录', en: 'Separate sign-in');
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

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
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(uiText(context, zh: '重试', en: 'Retry')),
          ),
        ],
      ),
    );
  }
}
