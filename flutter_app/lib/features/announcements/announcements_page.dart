import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/shared_colors.dart';
import '../../models/announcement_item.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  bool _loading = true;
  String? _error;
  String _activeType = '';
  List<AnnouncementItem> _announcements = const <AnnouncementItem>[];
  AnnouncementFilters _filters = const AnnouncementFilters(types: <String>[]);
  DailyAnnouncementSummary? _dailySummary;

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
      final repository = ref.read(announcementRepositoryProvider);
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.fetchAnnouncements(type: _activeType),
        repository.fetchFilters(),
        repository.fetchDailySummary(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _announcements = results[0] as List<AnnouncementItem>;
        _filters = results[1] as AnnouncementFilters;
        _dailySummary = results[2] as DailyAnnouncementSummary;
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if ((_dailySummary?.summary ?? '').trim().isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SharedColors.softRed.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _dailySummary!.title.trim().isEmpty
                        ? '每日公告摘要'
                        : _dailySummary!.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(_dailySummary!.summary),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _FilterChip(
                  label: '全部',
                  active: _activeType.isEmpty,
                  onTap: () => _selectType(''),
                ),
                for (final String type in _filters.types)
                  _FilterChip(
                    label: type,
                    active: _activeType == type,
                    onTap: () => _selectType(type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_announcements.isEmpty)
            const SizedBox(
              height: 260,
              child: Center(child: Text('暂无公告')),
            )
          else
            for (final AnnouncementItem item in _announcements)
              _AnnouncementCard(
                item: item,
                onTap: () => _openDetail(item.id),
              ),
        ],
      ),
    );
  }

  Future<void> _selectType(String type) async {
    if (_activeType == type) {
      return;
    }
    setState(() {
      _activeType = type;
    });
    await _load();
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementDetailPage(id: id),
      ),
    );
  }
}

class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  bool _loading = true;
  String? _error;
  AnnouncementItem? _item;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final AnnouncementItem item = await ref
          .read(announcementRepositoryProvider)
          .fetchAnnouncement(widget.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _item = item;
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
    final AnnouncementItem? item = _item;
    return Scaffold(
      appBar: AppBar(title: const Text('公告详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : item == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 80),
                      children: <Widget>[
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${item.publisher} · ${_dateText(item.publishedAt)}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.58),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.content,
                          style: const TextStyle(fontSize: 15, height: 1.75),
                        ),
                      ],
                    ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        selectedColor: primary.withValues(alpha: 0.12),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.onTap,
  });

  final AnnouncementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                if (item.displayType.isNotEmpty)
                  Text(
                    item.displayType,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (item.isImportant) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '重要',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            if (item.displaySummary.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                item.displaySummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: Text(item.publisher)),
                Text(_dateText(item.publishedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _dateText(DateTime? value) {
  if (value == null) {
    return '';
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
