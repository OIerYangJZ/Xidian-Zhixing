import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/campus_text.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
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
  int _groupIndex = 0;
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
      if (!mounted) return;
      setState(() {
        _services = (results[0] as List<CampusService>)
            .where((CampusService item) => item.hasBusinessAction)
            .toList();
        _today = results[1] as CampusTodaySchedules;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = uiTextGlobal(zh: '加载失败：$error', en: 'Could not load: $error');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final bool desktop = AppBreakpoints.isDesktop(context);
    final double shellScale = AppLayout.shellScale(
      MediaQuery.sizeOf(context).width,
    );
    final double scale = desktop ? shellScale : 1;
    final double panelWidth = desktop ? 888 * shellScale : double.infinity;
    final double panelRadius = desktop ? 34 * shellScale : 0;
    final List<CampusService> visible = _visibleServices(context);

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: desktop ? 61 * shellScale : 0),
        child: SizedBox(
          width: panelWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: EditorialColors.of(context).page,
              border: Border.all(color: EditorialColors.of(context).line),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(panelRadius),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(panelRadius),
              ),
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    if (_error != null)
                      _ErrorBanner(
                        message: _error!,
                        onRetry: _load,
                        scale: scale,
                      ),
                    _TodaySection(
                      today: _today,
                      scale: scale,
                      onOpenSchedule: _openScheduleSource,
                    ),
                    _ServicesHeader(
                      query: _query,
                      scale: scale,
                      onQueryChanged: (String value) => setState(() {
                        _query = value;
                      }),
                    ),
                    _GroupTabs(
                      selected: _groupIndex,
                      scale: scale,
                      onChanged: (int value) => setState(() {
                        _groupIndex = value;
                      }),
                    ),
                    _ServicesList(
                      services: visible,
                      scale: scale,
                      availableWidth: panelWidth == double.infinity
                          ? MediaQuery.sizeOf(context).width
                          : panelWidth,
                      desktop: desktop,
                      onOpen: _openService,
                    ),
                    _OfflineGame(scale: scale),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<CampusService> _visibleServices(BuildContext context) {
    final String query = _query.trim().toLowerCase();
    final String groupId = const <String>[
      'study',
      'life',
      'affairs',
      'tools',
    ][_groupIndex];
    return _services.where((CampusService service) {
      final String searchable = <String>[
        service.name,
        service.description,
        service.slug,
        localizedCampusServiceName(
          Localizations.localeOf(context),
          slug: service.slug,
          name: service.name,
        ),
        localizedCampusServiceDescription(
          Localizations.localeOf(context),
          slug: service.slug,
          description: service.description,
        ),
      ].join(' ').toLowerCase();
      final bool matchesQuery = query.isEmpty || searchable.contains(query);
      final bool matchesGroup = query.isNotEmpty || service.groupId == groupId;
      return matchesQuery && matchesGroup;
    }).toList();
  }

  void _openScheduleSource(CampusScheduleItem item) {
    final String slug = switch (item.source) {
      'examSchedules' => 'exam',
      'experimentSchedules' => 'experiment',
      _ => 'classtable',
    };
    final CampusService? service = _services
        .where((CampusService value) => value.slug == slug)
        .cast<CampusService?>()
        .firstOrNull;
    if (service != null) _openService(service);
  }

  Future<void> _openService(CampusService service) async {
    final CampusAction? action = service.actions
        .where((CampusAction item) => item.type != 'notice')
        .firstOrNull;
    if (service.slug == 'map' ||
        service.slug == 'campus-map' ||
        action?.type == 'map') {
      await launchUrl(
        Uri.parse('https://gis.xidian.edu.cn/#/home?campus=21047'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if ((service.groupId == 'quick' || service.kind == 'external') &&
        action?.type == 'external' &&
        (action?.url ?? '').trim().isNotEmpty) {
      final String target = action!.url.trim();
      if (AppConfig.isWebUrl(target)) {
        await launchUrl(
          Uri.parse(target),
          mode: LaunchMode.externalApplication,
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CampusServiceDetailPage(serviceId: service.id),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.today,
    required this.scale,
    required this.onOpenSchedule,
  });

  final CampusTodaySchedules today;
  final double scale;
  final ValueChanged<CampusScheduleItem> onOpenSchedule;

  String _todayLabel(CampusTodaySchedules value) {
    final DateTime now = DateTime.now();
    if (value.date.trim().isNotEmpty) return value.date.trim();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final bool empty = today.items.isEmpty;
    return _CampusSection(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  uiText(context, zh: '今日日程', en: 'Today'),
                  style: TextStyle(
                    fontSize: 22 * scale,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _todayLabel(today),
                style: TextStyle(
                  color: EditorialColors.of(context).mutedInk,
                  fontSize: 18 * scale,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 7 * scale),
          if (empty)
            Text(
              uiText(
                context,
                zh: '今天没有课表、考试或实验安排',
                en: 'No classes, exams or labs today',
              ),
              style: TextStyle(
                color: colors.mutedInk,
                fontSize: 18 * scale,
                height: 1.45,
              ),
            )
          else
            for (final CampusScheduleItem item in today.items.take(3))
              _ScheduleRow(
                item: item,
                scale: scale,
                onTap: () => onOpenSchedule(item),
              ),
        ],
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader({
    required this.query,
    required this.scale,
    required this.onQueryChanged,
  });

  final String query;
  final double scale;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return _CampusSection(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 52 * scale,
            padding: EdgeInsets.symmetric(horizontal: 18 * scale),
            decoration: BoxDecoration(
              color: EditorialColors.of(context).line.withValues(alpha: .38),
              borderRadius: BorderRadius.circular(30 * scale),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search,
                  size: 25 * scale,
                  color: EditorialColors.of(context).mutedInk,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: query)
                      ..selection = TextSelection.collapsed(
                        offset: query.length,
                      ),
                    onChanged: onQueryChanged,
                    style: TextStyle(fontSize: 21 * scale, height: 1.25),
                    decoration: InputDecoration(
                      hintText: uiText(
                        context,
                        zh: '搜索校园服务',
                        en: 'Search campus services',
                      ),
                      hintStyle: TextStyle(
                        color: EditorialColors.of(context).mutedInk,
                        fontSize: 21 * scale,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTabs extends StatelessWidget {
  const _GroupTabs({
    required this.selected,
    required this.scale,
    required this.onChanged,
  });

  final int selected;
  final double scale;
  final ValueChanged<int> onChanged;

  static const List<String> _zh = <String>['学习事务', '校园生活', '校务办理', '工具入口'];
  static const List<String> _en = <String>[
    'Academics',
    'Campus life',
    'Administration',
    'Tools',
  ];

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return SizedBox(
      height: 61 * scale,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 22 * scale),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < _zh.length; i++)
              InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 61 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == selected ? colors.ink : Colors.transparent,
                        width: 2 * scale,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    uiText(context, zh: _zh[i], en: _en[i]),
                    style: TextStyle(
                      color: i == selected ? colors.ink : colors.mutedInk,
                      fontSize: 21 * scale,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({
    required this.services,
    required this.scale,
    required this.availableWidth,
    required this.desktop,
    required this.onOpen,
  });

  final List<CampusService> services;
  final double scale;
  final double availableWidth;
  final bool desktop;
  final ValueChanged<CampusService> onOpen;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          33 * scale,
          26 * scale,
          33 * scale,
          26 * scale,
        ),
        child: Text(
          uiText(context, zh: '没有找到相关服务', en: 'No matching services'),
          style: TextStyle(
            color: EditorialColors.of(context).mutedInk,
            fontSize: 18 * scale,
          ),
        ),
      );
    }
    final List<Widget> serviceButtons = services
        .map(
          (CampusService service) => _ServiceButton(
            service: service,
            scale: scale,
            onTap: () => onOpen(service),
          ),
        )
        .toList();
    final Widget serviceGrid = desktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < serviceButtons.length; index += 2)
                      serviceButtons[index],
                  ],
                ),
              ),
              SizedBox(width: 30 * scale),
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (int index = 1; index < serviceButtons.length; index += 2)
                      serviceButtons[index],
                  ],
                ),
              ),
            ],
          )
        : Column(children: serviceButtons);
    return SizedBox(
      width: availableWidth,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 33 * scale),
        child: serviceGrid,
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.service,
    required this.scale,
    required this.onTap,
  });

  final CampusService service;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final EditorialColors colors = EditorialColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 88 * scale),
        padding: EdgeInsets.symmetric(vertical: 23 * scale),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: <Widget>[
            Icon(_iconForService(service), size: 25 * scale, color: colors.ink),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    localizedCampusServiceName(
                      locale,
                      slug: service.slug,
                      name: service.name,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 22 * scale, height: 1.2),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    localizedCampusServiceDescription(
                      locale,
                      slug: service.slug,
                      description: service.description,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.mutedInk,
                      fontSize: 18 * scale,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            Icon(Icons.chevron_right, size: 25 * scale, color: colors.mutedInk),
          ],
        ),
      ),
    );
  }

  IconData _iconForService(CampusService item) {
    final String text = '${item.slug} ${item.iconKey} ${item.name}';
    if (text.contains('calendar') ||
        text.contains('class') ||
        text.contains('exam') ||
        text.contains('课') ||
        text.contains('考试')) {
      return Icons.calendar_month_outlined;
    }
    if (text.contains('library') ||
        text.contains('book') ||
        text.contains('图书'))
      return Icons.menu_book_outlined;
    if (text.contains('map') || text.contains('地图')) return Icons.map_outlined;
    if (text.contains('water') || text.contains('水'))
      return Icons.water_drop_outlined;
    if (text.contains('school') ||
        text.contains('campus') ||
        text.contains('校'))
      return Icons.account_balance_outlined;
    return Icons.grid_view_rounded;
  }
}

class _OfflineGame extends StatefulWidget {
  const _OfflineGame({required this.scale});
  final double scale;

  @override
  State<_OfflineGame> createState() => _OfflineGameState();
}

class _OfflineGameState extends State<_OfflineGame> {
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final double s = widget.scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 33 * s, vertical: 23 * s),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              uiText(
                context,
                zh: '课间休息 · 离线小游戏',
                en: 'Take a break · Offline mini game',
              ),
              style: TextStyle(fontSize: 18 * s, color: colors.mutedInk),
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _score++),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22 * s),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 20 * s,
                vertical: 9 * s,
              ),
              minimumSize: Size(0, 44 * s),
            ),
            child: Text(
              '${uiText(context, zh: '跳跃', en: 'Jump')} $_score',
              style: TextStyle(fontSize: 18 * s),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampusSection extends StatelessWidget {
  const _CampusSection({required this.child, required this.scale});
  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        28 * scale,
        33 * scale,
        28 * scale,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: EditorialColors.of(context).line),
        ),
      ),
      child: child,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.item,
    required this.scale,
    required this.onTap,
  });
  final CampusScheduleItem item;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: 12 * scale),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(item.title, style: TextStyle(fontSize: 22 * scale)),
            ),
            Text(item.timeRange, style: TextStyle(fontSize: 18 * scale)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.scale,
  });
  final String message;
  final VoidCallback onRetry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16 * scale),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red, fontSize: 16 * scale),
            ),
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
