import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/campus_text.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../design_system/design_system.dart';
import '../../models/campus_models.dart';
import 'campus_auth_center_page.dart';
import 'campus_service_detail_page.dart';

/// 校园 (handoff C1): today's schedule, the week's timetable, upcoming
/// exams, campus maps and the service entries.
class CampusPage extends ConsumerStatefulWidget {
  const CampusPage({super.key});

  @override
  ConsumerState<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends ConsumerState<CampusPage> {
  static const Duration _examHorizon = Duration(days: 31);

  bool _loading = true;
  String? _error;
  List<CampusService> _services = const <CampusService>[];
  List<CampusMap> _maps = const <CampusMap>[];
  CampusTodaySchedules _today = const CampusTodaySchedules(
    date: '',
    items: <CampusScheduleItem>[],
  );
  List<CampusScheduleItem> _exams = const <CampusScheduleItem>[];

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
        repository.fetchCalendar(
          source: 'examSchedules',
          startDate: _isoDate(DateTime.now()),
          days: _examHorizon.inDays,
        ),
        repository.fetchMaps().catchError((Object _) => <CampusMap>[]),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _services = (results[0] as List<CampusService>)
            .where((CampusService item) => item.hasBusinessAction)
            .toList();
        _today = results[1] as CampusTodaySchedules;
        _exams = <CampusScheduleItem>[
          for (final CampusCalendarDay day
              in (results[2] as CampusCalendar).days)
            ...day.items,
        ];
        _maps = results[3] as List<CampusMap>;
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool wide = width >= 1180;
        final bool medium = width >= 760;
        final Widget today = _TodayCard(
          today: _today,
          onTap: _openScheduleSource,
        );
        final Widget timetable = _WeekTimetable(onOpen: _openScheduleSource);
        final Widget exams = _ExamsCard(exams: _exams, onTap: _openExams);
        final Widget maps = _MapsCard(maps: _maps, onOpen: _openMap);
        final Widget services = _ServicesCard(
          services: _services,
          onOpen: _openService,
        );
        const SizedBox gap = SizedBox(height: 16, width: 16);

        return ZxPaper(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                medium ? 28 : 16,
                medium ? 24 : 12,
                medium ? 28 : 16,
                110,
              ),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZxInlineMessage(
                      message: _error!,
                      tone: ZxMessageTone.danger,
                      actionLabel: uiText(context, zh: '重试', en: 'Retry'),
                      onAction: _load,
                    ),
                  ),
                _Hero(
                  dateLabel: _todayLabel(context),
                  compact: !medium,
                  onOpenAuth: _openAuthCenter,
                ),
                gap,
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 320,
                        child: Column(children: <Widget>[today, gap, maps]),
                      ),
                      gap,
                      Expanded(child: timetable),
                      gap,
                      SizedBox(width: 300, child: exams),
                    ],
                  )
                else if (medium) ...<Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: today),
                      gap,
                      Expanded(child: exams),
                    ],
                  ),
                  gap,
                  timetable,
                  gap,
                  maps,
                ] else ...<Widget>[
                  today,
                  gap,
                  timetable,
                  gap,
                  exams,
                  gap,
                  maps,
                ],
                gap,
                services,
              ],
            ),
          ),
        );
      },
    );
  }

  String _todayLabel(BuildContext context) {
    final DateTime now = DateTime.now();
    final Locale locale = Localizations.localeOf(context);
    final String weekday = localizedWeekdayLabel(
      locale,
      '一二三四五六日'[now.weekday - 1],
    );
    return '${_two(now.month)}-${_two(now.day)} $weekday';
  }

  void _openAuthCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CampusAuthCenterPage()),
    );
  }

  CampusService? _serviceBySlug(String slug) => _services
      .where((CampusService item) => item.slug == slug)
      .cast<CampusService?>()
      .firstOrNull;

  void _openScheduleSource(CampusScheduleItem item) {
    final String slug = switch (item.source) {
      'examSchedules' => 'exam',
      'experimentSchedules' => 'experiment',
      _ => 'classtable',
    };
    final CampusService? service = _serviceBySlug(slug);
    if (service != null) {
      _openService(service);
    }
  }

  void _openExams() {
    final CampusService? service = _serviceBySlug('exam');
    if (service != null) _openService(service);
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
    if (_opensExternally(service)) {
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

  Future<void> _openMap(CampusMap map) async {
    final String url = map.sourceUrl.trim();
    if (AppConfig.isWebUrl(url)) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await _openCampusMap();
    }
  }

  Future<void> _openCampusMap() async {
    await launchUrl(
      Uri.parse('https://gis.xidian.edu.cn/#/home?campus=21047'),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Whether [CampusPage] hands [service] to the browser rather than opening
/// its detail page; those carry the ↗ mark.
bool _opensExternally(CampusService service) {
  final CampusAction? action = service.actions
      .where((CampusAction item) => item.type != 'notice')
      .firstOrNull;
  return (service.groupId == 'quick' || service.kind == 'external') &&
      action?.type == 'external' &&
      action!.url.trim().isNotEmpty;
}

const List<String> _monthsEn = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

class _Hero extends StatelessWidget {
  const _Hero({
    required this.dateLabel,
    required this.compact,
    required this.onOpenAuth,
  });

  final String dateLabel;
  final bool compact;
  final VoidCallback onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          uiText(context, zh: '校园', en: 'Campus'),
          style: (compact ? ZxType.headline : ZxType.display).copyWith(
            color: t.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(dateLabel, style: ZxType.body.copyWith(color: t.text2)),
      ],
    );
    final Widget auth = Material(
      color: t.surface.withValues(alpha: 0.9),
      borderRadius: ZxRadius.cardAll,
      child: InkWell(
        key: const Key('campus-auth-entry'),
        borderRadius: ZxRadius.cardAll,
        onTap: onOpenAuth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: ZxRadius.cardAll,
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.successSoft,
                  borderRadius: ZxRadius.buttonAll,
                ),
                child: Icon(Icons.key_rounded, size: 19, color: t.success),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      uiText(
                        context,
                        zh: '校园系统登录',
                        en: 'Campus system sign-in',
                      ),
                      style: ZxType.label.copyWith(color: t.text),
                    ),
                    Text(
                      uiText(
                        context,
                        zh: '校园网自服务、宿舍水机',
                        en: 'Network self-service, dorm water',
                      ),
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
            ],
          ),
        ),
      ),
    );
    return ZxHeroWash(
      borderRadius: ZxRadius.cardAll,
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 26),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[title, const SizedBox(height: 14), auth],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  auth,
                ],
              ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: t.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: ZxType.title.copyWith(color: t.text)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.onTap});

  final CampusTodaySchedules today;
  final ValueChanged<CampusScheduleItem> onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return ZxCard(
      key: const Key('campus-today'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            icon: Icons.event_note_outlined,
            title: uiText(context, zh: '今日日程', en: 'Today'),
            trailing: today.items.isEmpty
                ? null
                : Text(
                    uiText(
                      context,
                      zh: '${today.items.length} 项',
                      en: '${today.items.length}',
                    ),
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
          ),
          if (today.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                uiText(
                  context,
                  zh: '今天没有课程和考试安排',
                  en: 'No classes or exams today',
                ),
                textAlign: TextAlign.center,
                style: ZxType.body.copyWith(color: t.text3),
              ),
            ),
          for (final CampusScheduleItem item in today.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: item.isActive ? t.primarySoft : t.bgSunk,
                borderRadius: ZxRadius.buttonAll,
                child: InkWell(
                  borderRadius: ZxRadius.buttonAll,
                  onTap: () => onTap(item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 52,
                          child: Text(
                            item.startTime,
                            style: ZxType.label.copyWith(
                              color: t.text,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
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
                                style: ZxType.label.copyWith(color: t.text),
                              ),
                              Text(
                                <String>[
                                  localizedScheduleSource(
                                    locale,
                                    item.sourceLabel,
                                  ),
                                  if (item.location.isNotEmpty) item.location,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZxType.caption.copyWith(color: t.text3),
                              ),
                            ],
                          ),
                        ),
                        if (item.isActive)
                          ZxBadge.inProgress(
                            uiText(context, zh: '进行中', en: 'Now'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The week's classes and exams on a period grid, with week navigation.
class _WeekTimetable extends ConsumerStatefulWidget {
  const _WeekTimetable({required this.onOpen});

  final ValueChanged<CampusScheduleItem> onOpen;

  @override
  ConsumerState<_WeekTimetable> createState() => _WeekTimetableState();
}

class _WeekTimetableState extends ConsumerState<_WeekTimetable> {
  /// Start times of the five two-period blocks (1–2 … 9–10).
  static const List<String> _slotStarts = <String>[
    '08:30',
    '10:25',
    '14:00',
    '15:55',
    '19:00',
  ];

  late DateTime _weekStart = _mondayOf(DateTime.now());
  CampusCalendar? _calendar;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isThisWeek => _weekStart == _mondayOf(DateTime.now());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CampusCalendar calendar = await ref
          .read(campusRepositoryProvider)
          .fetchCalendar(startDate: _isoDate(_weekStart));
      if (mounted) setState(() => _calendar = calendar);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int weeks) {
    _weekStart = _weekStart.add(Duration(days: 7 * weeks));
    _load();
  }

  void _thisWeek() {
    _weekStart = _mondayOf(DateTime.now());
    _load();
  }

  /// Which block [item] sits in: its section (`3-4` → 1) when given,
  /// otherwise the last block starting at or before it.
  static int slotOf(CampusScheduleItem item) {
    final Match? m = RegExp(r'^\s*(\d+)').firstMatch(item.section);
    if (m != null) {
      return ((int.parse(m.group(1)!) - 1) ~/ 2).clamp(0, 4);
    }
    int slot = 0;
    for (int i = 0; i < _slotStarts.length; i++) {
      if (item.startTime.compareTo(_slotStarts[i]) >= 0) slot = i;
    }
    return slot;
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final DateTime end = _weekStart.add(const Duration(days: 6));
    final List<CampusCalendarDay> days =
        _calendar?.days ?? const <CampusCalendarDay>[];
    final bool weekendUsed = days
        .skip(5)
        .any((CampusCalendarDay d) => d.items.isNotEmpty);

    return ZxCard(
      key: const Key('campus-timetable'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.grid_view_rounded, size: 18, color: t.primary),
                  const SizedBox(width: 8),
                  Text(
                    uiText(context, zh: '课表', en: 'Timetable'),
                    style: ZxType.title.copyWith(color: t.text),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: t.bgSunk,
                      borderRadius: ZxRadius.buttonAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          key: const Key('timetable-prev'),
                          visualDensity: VisualDensity.compact,
                          tooltip: uiText(
                            context,
                            zh: '上一周',
                            en: 'Previous week',
                          ),
                          onPressed: _loading ? null : () => _shift(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '${_two(_weekStart.month)}-${_two(_weekStart.day)} '
                          '${uiText(context, zh: '至', en: 'to')} '
                          '${_two(end.month)}-${_two(end.day)}',
                          style: ZxType.label.copyWith(color: t.text),
                        ),
                        IconButton(
                          key: const Key('timetable-next'),
                          visualDensity: VisualDensity.compact,
                          tooltip: uiText(context, zh: '下一周', en: 'Next week'),
                          onPressed: _loading ? null : () => _shift(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (!_isThisWeek) ...<Widget>[
                    const SizedBox(width: 8),
                    ZxButton(
                      key: const Key('timetable-this-week'),
                      label: uiText(context, zh: '回到本周', en: 'This week'),
                      variant: ZxButtonVariant.secondary,
                      small: true,
                      onPressed: _thisWeek,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null && _calendar == null)
            ZxInlineMessage(
              message: uiText(
                context,
                zh: '课表加载失败：$_error',
                en: 'Could not load the timetable: $_error',
              ),
              tone: ZxMessageTone.danger,
              actionLabel: uiText(context, zh: '重试', en: 'Retry'),
              onAction: _load,
            )
          else if (_calendar == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final List<CampusCalendarDay> shown =
                    c.maxWidth < 560 && !weekendUsed
                    ? days.take(5).toList()
                    : days;
                return _grid(context, t, locale, shown, c.maxWidth);
              },
            ),
          if (_calendar != null &&
              days.every((CampusCalendarDay d) => d.items.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                uiText(
                  context,
                  zh: '这一周没有课程安排',
                  en: 'Nothing scheduled this week',
                ),
                textAlign: TextAlign.center,
                style: ZxType.caption.copyWith(color: t.text3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    ZxTokens t,
    Locale locale,
    List<CampusCalendarDay> days,
    double width,
  ) {
    const double labelWidth = 48;
    const double gap = 4;
    final double column =
        ((width - labelWidth - gap * days.length) / days.length).clamp(44, 140);
    Widget cell(CampusCalendarDay day, int slot) {
      final List<CampusScheduleItem> items = day.items
          .where((CampusScheduleItem i) => slotOf(i) == slot)
          .toList();
      if (items.isEmpty) {
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: t.bgSunk.withValues(alpha: 0.6),
            borderRadius: ZxRadius.smallButtonAll,
          ),
        );
      }
      final CampusScheduleItem item = items.first;
      final Color hue = item.isExam ? t.danger : t.channelFor(item.title);
      return Material(
        color: Color.lerp(hue, t.surface, 0.84),
        borderRadius: ZxRadius.smallButtonAll,
        child: InkWell(
          borderRadius: ZxRadius.smallButtonAll,
          onTap: () => widget.onOpen(item),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: day.isToday
                ? BoxDecoration(
                    borderRadius: ZxRadius.smallButtonAll,
                    border: Border.all(color: hue.withValues(alpha: 0.5)),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  items.length > 1
                      ? '${item.title} +${items.length - 1}'
                      : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.micro.copyWith(
                    color: Color.lerp(hue, t.text, 0.35),
                  ),
                ),
                const Spacer(),
                Text(
                  item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.micro.copyWith(
                    color: t.text3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: labelWidth),
              for (final CampusCalendarDay day in days) ...<Widget>[
                const SizedBox(width: gap),
                Container(
                  width: column,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: day.isToday ? t.primary : null,
                    borderRadius: ZxRadius.smallButtonAll,
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        localizedWeekdayLabel(locale, day.weekday),
                        style: ZxType.micro.copyWith(
                          color: day.isToday ? t.onPrimary : t.text,
                        ),
                      ),
                      Text(
                        day.date.length >= 10
                            ? day.date.substring(5)
                            : day.date,
                        style: ZxType.micro.copyWith(
                          color: day.isToday
                              ? t.onPrimary.withValues(alpha: 0.85)
                              : t.text3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          for (int slot = 0; slot < _slotStarts.length; slot++)
            Padding(
              padding: const EdgeInsets.only(top: gap),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: labelWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${slot * 2 + 1}–${slot * 2 + 2}',
                          style: ZxType.micro.copyWith(color: t.text),
                        ),
                        Text(
                          _slotStarts[slot],
                          style: ZxType.micro.copyWith(
                            color: t.text3,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final CampusCalendarDay day in days) ...<Widget>[
                    const SizedBox(width: gap),
                    SizedBox(width: column, child: cell(day, slot)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExamsCard extends StatelessWidget {
  const _ExamsCard({required this.exams, required this.onTap});

  final List<CampusScheduleItem> exams;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final DateTime today = DateTime.now();
    final DateTime day0 = DateTime(today.year, today.month, today.day);
    return ZxCard(
      key: const Key('campus-exams'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            icon: Icons.assignment_outlined,
            title: uiText(context, zh: '考试', en: 'Exams'),
            trailing: exams.isEmpty
                ? null
                : TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: t.primary,
                    ),
                    child: Text(
                      uiText(
                        context,
                        zh: '全部 ${exams.length} 场',
                        en: 'All ${exams.length}',
                      ),
                      style: ZxType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          if (exams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                uiText(
                  context,
                  zh: '近一个月没有考试安排',
                  en: 'No exams in the next month',
                ),
                textAlign: TextAlign.center,
                style: ZxType.body.copyWith(color: t.text3),
              ),
            ),
          for (final CampusScheduleItem exam in exams.take(4))
            Builder(
              builder: (BuildContext context) {
                final DateTime? date = DateTime.tryParse(exam.date);
                final int? inDays = date?.difference(day0).inDays;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.bgSunk,
                      borderRadius: ZxRadius.buttonAll,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 40,
                          child: Column(
                            children: <Widget>[
                              Text(
                                date == null ? '--' : _two(date.day),
                                style: ZxType.title.copyWith(color: t.text),
                              ),
                              Text(
                                date == null
                                    ? ''
                                    : uiText(
                                        context,
                                        zh: '${date.month} 月',
                                        en: _monthsEn[date.month - 1],
                                      ),
                                style: ZxType.micro.copyWith(
                                  color: t.text3,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                exam.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ZxType.label.copyWith(color: t.text),
                              ),
                              Text(
                                <String>[
                                  if (exam.startTime.isNotEmpty) exam.startTime,
                                  if (exam.location.isNotEmpty) exam.location,
                                  if (exam.seatNo.isNotEmpty)
                                    uiText(
                                      context,
                                      zh: '座位 ${exam.seatNo}',
                                      en: 'Seat ${exam.seatNo}',
                                    ),
                                ].join(' · '),
                                style: ZxType.caption.copyWith(color: t.text3),
                              ),
                            ],
                          ),
                        ),
                        if (inDays != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: inDays <= 14 ? t.accentSoft : t.surface,
                              borderRadius: ZxRadius.badgeAll,
                            ),
                            child: Text(
                              inDays == 0
                                  ? uiText(context, zh: '今天', en: 'Today')
                                  : uiText(
                                      context,
                                      zh: '$inDays 天',
                                      en: '${inDays}d',
                                    ),
                              style: ZxType.micro.copyWith(
                                color: inDays <= 14 ? t.accentInk : t.text2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MapsCard extends StatelessWidget {
  const _MapsCard({required this.maps, required this.onOpen});

  final List<CampusMap> maps;
  final ValueChanged<CampusMap> onOpen;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final List<CampusMap> shown = maps.isEmpty
        ? <CampusMap>[
            CampusMap(
              id: 'gis',
              name: uiText(context, zh: '西电校园地图', en: 'Xidian campus map'),
              description: uiText(
                context,
                zh: '教学楼、食堂、快递点',
                en: 'Buildings, canteens, parcel points',
              ),
              sourceUrl: '',
            ),
          ]
        : maps;
    return ZxCard(
      key: const Key('campus-maps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            icon: Icons.place_outlined,
            title: uiText(context, zh: '校园地图', en: 'Campus map'),
          ),
          for (final CampusMap map in shown)
            ZxListItem(
              icon: Icons.map_outlined,
              iconColor: t.success,
              title: localizedCampusMapName(locale, map.name),
              subtitle: map.description.isEmpty
                  ? null
                  : localizedCampusMapDescription(locale, map.description),
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: t.text3,
              ),
              onTap: () => onOpen(map),
            ),
        ],
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.services, required this.onOpen});

  final List<CampusService> services;
  final ValueChanged<CampusService> onOpen;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    return ZxCard(
      key: const Key('campus-services'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            icon: Icons.apps_rounded,
            title: uiText(context, zh: '服务入口', en: 'Services'),
            trailing: Text(
              uiText(context, zh: '带 ↗ 的在新标签页打开', en: '↗ opens in a new tab'),
              style: ZxType.caption.copyWith(color: t.text3),
            ),
          ),
          if (services.isEmpty)
            Text(
              uiText(context, zh: '暂时没有可用的服务', en: 'No services yet'),
              style: ZxType.body.copyWith(color: t.text3),
            ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int columns = c.maxWidth >= 1000
                  ? 6
                  : c.maxWidth >= 700
                  ? 4
                  : c.maxWidth >= 420
                  ? 3
                  : 2;
              final double width = (c.maxWidth - 10 * (columns - 1)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final CampusService service in services)
                    SizedBox(
                      width: width,
                      child: _ServiceTile(
                        service: service,
                        name: localizedCampusServiceName(
                          locale,
                          slug: service.slug,
                          name: service.name,
                        ),
                        external: _opensExternally(service),
                        onTap: () => onOpen(service),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.name,
    required this.external,
    required this.onTap,
  });

  final CampusService service;
  final String name;
  final bool external;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color hue = t.channelFor(service.slug);
    return Material(
      color: t.bgSunk,
      borderRadius: ZxRadius.buttonAll,
      child: InkWell(
        borderRadius: ZxRadius.buttonAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color.lerp(hue, t.surface, 0.82),
                  borderRadius: ZxRadius.smallButtonAll,
                ),
                child: Icon(_iconFor(service), size: 18, color: hue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZxType.label.copyWith(color: t.text),
                ),
              ),
              if (external)
                Icon(Icons.north_east_rounded, size: 14, color: t.text3),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CampusService service) {
    final String text = '${service.slug} ${service.iconKey} ${service.name}';
    if (text.contains('map') || text.contains('地图')) return Icons.map_outlined;
    if (text.contains('exam') || text.contains('考试')) {
      return Icons.assignment_outlined;
    }
    if (text.contains('class') || text.contains('课表')) {
      return Icons.calendar_month_outlined;
    }
    if (text.contains('library') || text.contains('图书')) {
      return Icons.local_library_outlined;
    }
    if (text.contains('water') || text.contains('水')) {
      return Icons.water_drop_outlined;
    }
    if (text.contains('实验')) return Icons.science_outlined;
    if (text.contains('net') || text.contains('网')) return Icons.wifi_rounded;
    if (text.contains('mail') || text.contains('邮')) {
      return Icons.mail_outline_rounded;
    }
    if (text.contains('card') || text.contains('一卡通')) {
      return Icons.badge_outlined;
    }
    if (text.contains('room') || text.contains('教室')) {
      return Icons.meeting_room_outlined;
    }
    if (text.contains('guide') || text.contains('指南')) {
      return Icons.menu_book_outlined;
    }
    return Icons.apps_rounded;
  }
}
