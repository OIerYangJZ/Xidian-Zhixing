import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/campus_text.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/shared_colors.dart';
import '../../models/campus_models.dart';

class CampusServiceDetailPage extends ConsumerStatefulWidget {
  const CampusServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<CampusServiceDetailPage> createState() =>
      _CampusServiceDetailPageState();
}

class _CampusServiceDetailPageState
    extends ConsumerState<CampusServiceDetailPage> {
  static const List<_SectionRow> _sectionRows = <_SectionRow>[
    _SectionRow(1, '08:30', '09:15', '上午'),
    _SectionRow(2, '09:20', '10:05', ''),
    _SectionRow(3, '10:25', '11:10', ''),
    _SectionRow(4, '11:15', '12:00', ''),
    _SectionRow(5, '14:00', '14:45', '下午'),
    _SectionRow(6, '14:50', '15:35', ''),
    _SectionRow(7, '15:55', '16:40', ''),
    _SectionRow(8, '16:45', '17:30', ''),
    _SectionRow(9, '19:00', '19:45', '晚上'),
    _SectionRow(10, '19:50', '20:35', ''),
    _SectionRow(11, '20:40', '21:25', ''),
  ];

  bool _loading = true;
  String? _error;
  CampusService? _service;
  CampusCalendar? _calendar;
  DateTime _weekStart = _mondayOf(DateTime.now());

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
      final CampusService service = await repository.fetchServiceDetail(
        widget.serviceId,
      );
      CampusCalendar? calendar;
      if (service.kind == 'schedule' || service.calendarSource.isNotEmpty) {
        calendar = await repository.fetchCalendar(
          source: _calendarSourceFor(service),
          startDate: _ymd(_weekStart),
          days: _isExamService(service) ? 31 : 7,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _service = service;
        _calendar = calendar;
        if ((calendar?.startDate ?? '').isNotEmpty) {
          _weekStart = DateTime.parse('${calendar!.startDate}T00:00:00');
        }
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

  Future<void> _reloadCalendar() async {
    final CampusService? service = _service;
    if (service == null ||
        !(service.kind == 'schedule' || service.calendarSource.isNotEmpty)) {
      return;
    }
    final CampusCalendar calendar = await ref
        .read(campusRepositoryProvider)
        .fetchCalendar(
          source: _calendarSourceFor(service),
          startDate: _ymd(_weekStart),
          days: _isExamService(service) ? 31 : 7,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _calendar = calendar;
      if (calendar.startDate.isNotEmpty) {
        _weekStart = DateTime.parse('${calendar.startDate}T00:00:00');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CampusService? service = _service;
    final Locale locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: _isClasstable(service)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: uiText(context, zh: '上一周', en: 'Previous week'),
                    onPressed: () => _shiftWeek(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  TextButton(onPressed: _pickWeek, child: Text(_weekTitle())),
                  IconButton(
                    tooltip: uiText(context, zh: '下一周', en: 'Next week'),
                    onPressed: () => _shiftWeek(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              )
            : Text(
                service == null
                    ? uiText(context, zh: '校园服务', en: 'Campus services')
                    : localizedCampusServiceName(
                        locale,
                        slug: service.slug,
                        name: service.name,
                      ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : service == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: <Widget>[
                if (_isExamService(service))
                  _ExamList(calendar: _calendar)
                else if (service.kind == 'schedule' ||
                    service.calendarSource.isNotEmpty)
                  _ScheduleGrid(calendar: _calendar, sectionRows: _sectionRows),
                if (_businessActions(service).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _BlockTitle(uiText(context, zh: '操作', en: 'Actions')),
                  const SizedBox(height: 10),
                  _ActionGrid(
                    actions: _businessActions(service),
                    onTap: _runAction,
                  ),
                ],
                if (service.maps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _BlockTitle(uiText(context, zh: '相关地图', en: 'Related maps')),
                  const SizedBox(height: 10),
                  for (final CampusMap map in service.maps)
                    _MapRow(map: map, onTap: _openCampusMap),
                ],
              ],
            ),
    );
  }

  List<CampusAction> _businessActions(CampusService service) {
    return service.actions
        .where(
          (CampusAction item) =>
              item.type != 'calendar' && item.type != 'notice',
        )
        .toList();
  }

  bool _isClasstable(CampusService? service) => service?.slug == 'classtable';

  bool _isExamService(CampusService service) =>
      service.slug == 'exam' || service.calendarSource == 'examSchedules';

  String _calendarSourceFor(CampusService service) {
    if (_isExamService(service)) {
      return 'examSchedules';
    }
    if (service.calendarSource == 'courseSchedules' ||
        service.calendarSource == 'examSchedules') {
      return 'academic';
    }
    return service.calendarSource.isEmpty ? 'academic' : service.calendarSource;
  }

  Future<void> _shiftWeek(int delta) async {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
    await _reloadCalendar();
  }

  Future<void> _pickWeek() async {
    final DateTime current = _mondayOf(DateTime.now());
    final List<DateTime> weeks = List<DateTime>.generate(
      25,
      (int index) => current.add(Duration(days: (index - 12) * 7)),
    );
    final DateTime? selected = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final DateTime week in weeks)
              ListTile(
                title: Text(
                  '${_ymd(week)} - ${_ymd(week.add(const Duration(days: 6)))}',
                ),
                trailing: _ymd(week) == _ymd(_weekStart)
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(week),
              ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _weekStart = selected;
    });
    await _reloadCalendar();
  }

  Future<void> _runAction(CampusAction action) async {
    if (action.type == 'map') {
      await _openCampusMap();
      return;
    }
    final String target = action.url.trim();
    // Server-supplied url: only plain web schemes may reach the system
    // launcher, and Uri.parse throws on malformed input.
    if (target.isNotEmpty && AppConfig.isWebUrl(target)) {
      await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openCampusMap() async {
    await launchUrl(
      Uri.parse('https://gis.xidian.edu.cn/#/home?campus=21047'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _weekTitle() {
    final String start = _ymd(_weekStart);
    final String end = _ymd(_weekStart.add(const Duration(days: 6)));
    return '$start - $end';
  }

  static DateTime _mondayOf(DateTime date) {
    final DateTime base = DateTime(date.year, date.month, date.day);
    return base.subtract(Duration(days: base.weekday - 1));
  }

  static String _ymd(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({required this.calendar, required this.sectionRows});

  final CampusCalendar? calendar;
  final List<_SectionRow> sectionRows;

  @override
  Widget build(BuildContext context) {
    final CampusCalendar? data = calendar;
    if (data == null ||
        data.days.every((CampusCalendarDay day) => day.items.isEmpty)) {
      return _EmptyBlock(
        text: uiText(
          context,
          zh: '本周暂无课表或考试安排',
          en: 'No classes or exams scheduled this week',
        ),
      );
    }
    const double timeWidth = 72;
    const double dayWidth = 132;
    const double headerHeight = 56;
    const double rowHeight = 78;
    final double width = timeWidth + dayWidth * data.days.length;
    final double height = headerHeight + rowHeight * sectionRows.length;
    final List<_ScheduleBlock> blocks = _buildBlocks(data.days, sectionRows);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: <Widget>[
            for (int day = 0; day < data.days.length; day++)
              Positioned(
                left: timeWidth + day * dayWidth,
                top: 0,
                width: dayWidth,
                height: headerHeight,
                child: _DayHeader(day: data.days[day]),
              ),
            for (int row = 0; row < sectionRows.length; row++)
              Positioned(
                left: 0,
                top: headerHeight + row * rowHeight,
                width: timeWidth,
                height: rowHeight,
                child: _TimeCell(row: sectionRows[row]),
              ),
            for (int row = 0; row < sectionRows.length; row++)
              for (int day = 0; day < data.days.length; day++)
                Positioned(
                  left: timeWidth + day * dayWidth,
                  top: headerHeight + row * rowHeight,
                  width: dayWidth,
                  height: rowHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: SharedColors.divider),
                    ),
                  ),
                ),
            for (final _ScheduleBlock block in blocks)
              Positioned(
                left: timeWidth + block.dayIndex * dayWidth + 5,
                top: headerHeight + block.rowIndex * rowHeight + 5,
                width: dayWidth - 10,
                height: rowHeight * block.span - 10,
                child: _ScheduleCard(block: block),
              ),
          ],
        ),
      ),
    );
  }

  List<_ScheduleBlock> _buildBlocks(
    List<CampusCalendarDay> days,
    List<_SectionRow> rows,
  ) {
    final List<_ScheduleBlock> blocks = <_ScheduleBlock>[];
    for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
      for (final CampusScheduleItem item in days[dayIndex].items) {
        final int start = _sectionForTime(item.startTime, rows);
        final int end = _sectionForTime(item.endTime, rows);
        blocks.add(
          _ScheduleBlock(
            item: item,
            dayIndex: dayIndex,
            rowIndex: start - 1,
            span: (end - start + 1).clamp(1, 4),
          ),
        );
      }
    }
    return blocks;
  }

  int _sectionForTime(String value, List<_SectionRow> rows) {
    final int target = _minutes(value);
    int best = rows.first.section;
    for (final _SectionRow row in rows) {
      if (target >= _minutes(row.start)) {
        best = row.section;
      }
    }
    return best;
  }

  int _minutes(String value) {
    final List<String> parts = value.split(':');
    if (parts.length != 2) {
      return 0;
    }
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final CampusCalendarDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SharedColors.divider)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            localizedWeekdayLabel(Localizations.localeOf(context), day.weekday),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(day.date.length >= 10 ? day.date.substring(8) : day.date),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.row});

  final _SectionRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: SharedColors.divider),
          bottom: BorderSide(color: SharedColors.divider),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            localizedDayPeriod(Localizations.localeOf(context), row.period),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            '${row.section}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(row.start, style: const TextStyle(fontSize: 10)),
          Text(row.end, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.block});

  final _ScheduleBlock block;

  @override
  Widget build(BuildContext context) {
    final bool isExam = block.item.isExam;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isExam
            ? SharedColors.primary.withValues(alpha: 0.12)
            : SharedColors.softRed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExam
              ? SharedColors.primary.withValues(alpha: 0.22)
              : SharedColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isExam && !block.item.title.endsWith('考试')
                ? uiText(
                    context,
                    zh: '${block.item.title}考试',
                    en: '${block.item.title} exam',
                  )
                : block.item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            block.item.location,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          if (block.item.teacher.isNotEmpty)
            Text(
              block.item.teacher,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _ExamList extends StatelessWidget {
  const _ExamList({required this.calendar});

  final CampusCalendar? calendar;

  @override
  Widget build(BuildContext context) {
    final List<CampusScheduleItem> items =
        <CampusScheduleItem>[
          for (final CampusCalendarDay day
              in calendar?.days ?? const <CampusCalendarDay>[])
            ...day.items,
        ]..sort(
          (CampusScheduleItem a, CampusScheduleItem b) =>
              '${a.date} ${a.startTime} ${a.id}'.compareTo(
                '${b.date} ${b.startTime} ${b.id}',
              ),
        );
    if (items.isEmpty) {
      return _EmptyBlock(
        text: uiText(context, zh: '暂无考试安排', en: 'No exams scheduled'),
      );
    }
    return Column(
      children: <Widget>[
        for (final CampusScheduleItem item in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SharedColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.date,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: uiText(context, zh: '时间', en: 'Time'),
                  value: item.timeRange,
                ),
                if (item.location.isNotEmpty)
                  _InfoRow(
                    label: uiText(context, zh: '地点', en: 'Room'),
                    value: item.location,
                  ),
                if ((item.seatNo.isNotEmpty || item.section.isNotEmpty))
                  _InfoRow(
                    label: uiText(context, zh: '座位号', en: 'Seat'),
                    value: item.seatNo.isNotEmpty ? item.seatNo : item.section,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions, required this.onTap});

  final List<CampusAction> actions;
  final ValueChanged<CampusAction> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final CampusAction action in actions)
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: () => onTap(action),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                localizedCampusActionLabel(
                  Localizations.localeOf(context),
                  action.label,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapRow extends StatelessWidget {
  const _MapRow({required this.map, required this.onTap});

  final CampusMap map;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(localizedCampusMapName(locale, map.name)),
      subtitle: map.description.isEmpty
          ? null
          : Text(localizedCampusMapDescription(locale, map.description)),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: SharedColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}

class _SectionRow {
  const _SectionRow(this.section, this.start, this.end, this.period);

  final int section;
  final String start;
  final String end;
  final String period;
}

class _ScheduleBlock {
  const _ScheduleBlock({
    required this.item,
    required this.dayIndex,
    required this.rowIndex,
    required this.span,
  });

  final CampusScheduleItem item;
  final int dayIndex;
  final int rowIndex;
  final int span;
}
