// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:get/get.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/experiment_controller.dart';
import 'package:watermeter/model/toolbox_addresses.dart';
import 'package:watermeter/page/class_attendance/class_attendance_view.dart';
import 'package:watermeter/page/dorm_water/dorm_water_window.dart';
import 'package:watermeter/page/empty_classroom/empty_classroom_window.dart';
import 'package:watermeter/page/exam/exam_info_window.dart';
import 'package:watermeter/page/experiment/experiment_window.dart';
import 'package:watermeter/page/homepage/info_widget/classtable_card.dart';
import 'package:watermeter/page/homepage/info_widget/electricity_card.dart';
import 'package:watermeter/page/homepage/info_widget/library_card.dart';
import 'package:watermeter/page/homepage/info_widget/school_card_info_card.dart';
import 'package:watermeter/page/homepage/info_widget/schoolnet_card.dart';
import 'package:watermeter/page/homepage/refresh.dart';
import 'package:watermeter/page/homepage/small_function_card.dart';
import 'package:watermeter/page/login/jc_captcha.dart';
import 'package:watermeter/page/public_widget/context_extension.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:watermeter/page/score/score.dart';
import 'package:watermeter/page/setting/dialogs/sport_password_dialog.dart';
import 'package:watermeter/page/sport/sport_window.dart';
import 'package:watermeter/repository/notification/course_reminder_service.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as prefs;
import 'package:watermeter/repository/xidian_ids/ids_session.dart';
import 'package:watermeter/repository/xidian_ids/score_session.dart';

class _HomeFunctionEntry {
  final String id;
  final String nameKey;
  final IconData iconData;
  final bool undergraduateOnly;
  final Future<void> Function(BuildContext context) onTap;

  const _HomeFunctionEntry({
    required this.id,
    required this.nameKey,
    required this.iconData,
    required this.onTap,
    this.undergraduateOnly = false,
  });
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final Map<String, _HomeFunctionEntry> _functionRegistry;
  late List<String> _functionOrder;
  late Set<String> _hiddenFunctionIds;
  bool _isCustomizing = false;

  @override
  void initState() {
    super.initState();
    Get.put(ClassTableController());
    Get.put(ExamController());
    Get.put(ExperimentController());

    _functionRegistry = _buildFunctionRegistry();
    _restoreFunctionLayout();

    // Validate and update notifications after controllers are initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await CourseReminderService().initialize();
        await CourseReminderService().validateAndUpdateNotifications();
        log.info(
          "Notifications validated and updated after homepage initialization.",
        );
      } catch (e, stackTrace) {
        log.error(
          "Failed to validate notifications after homepage initialization",
          e,
          stackTrace,
        );
      }
    });
  }

  String get _now {
    final DateTime now = DateTime.now();

    if (now.hour >= 5 && now.hour < 9) {
      return "homepage.time_string.morning";
    }
    if (now.hour >= 9 && now.hour < 11) {
      return "homepage.time_string.before_noon";
    }
    if (now.hour >= 11 && now.hour < 14) {
      return "homepage.time_string.at_noon";
    }
    if (now.hour >= 14 && now.hour < 18) {
      return "homepage.time_string.afternoon";
    }
    if (now.hour >= 18 || now.hour == 0) {
      return "homepage.time_string.night";
    }
    return "homepage.time_string.midnight";
  }

  bool get _isPostgraduate => prefs.getBool(prefs.Preference.role);

  List<String> get _availableFunctionIds => _functionRegistry.values
      .where((entry) => !entry.undergraduateOnly || !_isPostgraduate)
      .map((entry) => entry.id)
      .toList(growable: false);

  List<_HomeFunctionEntry> get _visibleFunctions => _functionOrder
      .map((id) => _functionRegistry[id])
      .whereType<_HomeFunctionEntry>()
      .toList(growable: false);

  List<_HomeFunctionEntry> get _hiddenFunctions => _hiddenFunctionIds
      .map((id) => _functionRegistry[id])
      .whereType<_HomeFunctionEntry>()
      .toList(growable: false);

  Map<String, _HomeFunctionEntry> _buildFunctionRegistry() {
    final registry = <String, _HomeFunctionEntry>{
      "score": _HomeFunctionEntry(
        id: "score",
        nameKey: "homepage.toolbox.score",
        iconData: Icons.grading_rounded,
        onTap: _openScore,
      ),
      "exam": _HomeFunctionEntry(
        id: "exam",
        nameKey: "homepage.toolbox.exam",
        iconData: MingCuteIcons.mgc_calendar_line,
        onTap: _openExam,
      ),
      "empty_classroom": _HomeFunctionEntry(
        id: "empty_classroom",
        nameKey: "homepage.toolbox.empty_classroom",
        iconData: MingCuteIcons.mgc_building_2_line,
        onTap: _openEmptyClassroom,
      ),
      "class_attendance": _HomeFunctionEntry(
        id: "class_attendance",
        nameKey: "homepage.toolbox.class_attendance",
        iconData: Icons.punch_clock_outlined,
        onTap: _openClassAttendance,
      ),
      "experiment": _HomeFunctionEntry(
        id: "experiment",
        nameKey: "homepage.toolbox.experiment",
        iconData: MingCuteIcons.mgc_science_line,
        onTap: _openExperiment,
        undergraduateOnly: true,
      ),
      "sport": _HomeFunctionEntry(
        id: "sport",
        nameKey: "homepage.toolbox.sport",
        iconData: MingCuteIcons.mgc_run_fill,
        onTap: _openSport,
        undergraduateOnly: true,
      ),
      "dorm_water": _HomeFunctionEntry(
        id: "dorm_water",
        nameKey: "homepage.toolbox.dorm_water",
        iconData: MingCuteIcons.mgc_teacup_line,
        onTap: _openDormWater,
        undergraduateOnly: true,
      ),
    };

    for (final entry in toolboxEntries) {
      registry[entry.id] = _HomeFunctionEntry(
        id: entry.id,
        nameKey: entry.nameKey,
        iconData: entry.iconData,
        onTap: (_) => _openExternal(entry.url),
      );
    }
    return registry;
  }

  void _restoreFunctionLayout() {
    final availableIds = _availableFunctionIds;
    final availableIdSet = availableIds.toSet();

    final savedOrder = _decodeIdList(
      prefs.getString(prefs.Preference.homeFunctionOrder),
    );
    final savedHidden = _decodeIdList(
      prefs.getString(prefs.Preference.homeHiddenFunctions),
    );

    _hiddenFunctionIds = savedHidden
        .where((id) => availableIdSet.contains(id))
        .toSet();

    _functionOrder = <String>[];
    for (final id in savedOrder) {
      if (!availableIdSet.contains(id) || _hiddenFunctionIds.contains(id)) {
        continue;
      }
      if (_functionOrder.contains(id)) {
        continue;
      }
      _functionOrder.add(id);
    }

    for (final id in availableIds) {
      if (_hiddenFunctionIds.contains(id) || _functionOrder.contains(id)) {
        continue;
      }
      _functionOrder.add(id);
    }

    _ensureAtLeastOneVisible();
  }

  List<String> _decodeIdList(String raw) {
    if (raw.trim().isEmpty) {
      return <String>[];
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed.whereType<String>().toList(growable: false);
      }
    } catch (_) {}
    return raw
        .split(",")
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  void _ensureAtLeastOneVisible() {
    if (_functionOrder.isNotEmpty) {
      return;
    }
    final availableIds = _availableFunctionIds;
    if (availableIds.isEmpty) {
      return;
    }
    final fallbackId = availableIds.first;
    _hiddenFunctionIds.remove(fallbackId);
    _functionOrder = <String>[fallbackId];
  }

  Future<void> _persistFunctionLayout() async {
    final hidden = _hiddenFunctionIds.toList(growable: false)..sort();
    await prefs.setString(
      prefs.Preference.homeFunctionOrder,
      jsonEncode(_functionOrder),
    );
    await prefs.setString(
      prefs.Preference.homeHiddenFunctions,
      jsonEncode(hidden),
    );
  }

  void _enterCustomizeMode() {
    setState(() {
      _isCustomizing = true;
    });
  }

  void _exitCustomizeMode() {
    setState(() {
      _isCustomizing = false;
    });
  }

  void _moveFunction(String draggedId, String targetId) {
    final oldIndex = _functionOrder.indexOf(draggedId);
    final newIndex = _functionOrder.indexOf(targetId);
    if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) {
      return;
    }

    setState(() {
      final movedId = _functionOrder.removeAt(oldIndex);
      final insertIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
      _functionOrder.insert(insertIndex, movedId);
    });
    unawaited(_persistFunctionLayout());
  }

  void _hideFunction(String id) {
    if (_functionOrder.length <= 1) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.customize.keep_one"),
      );
      return;
    }
    setState(() {
      _functionOrder.remove(id);
      _hiddenFunctionIds.add(id);
    });
    unawaited(_persistFunctionLayout());
  }

  void _addHiddenFunction(String id) {
    setState(() {
      _hiddenFunctionIds.remove(id);
      if (!_functionOrder.contains(id)) {
        _functionOrder.add(id);
      }
    });
    unawaited(_persistFunctionLayout());
  }

  Future<void> _showAddHiddenFunctionsSheet() async {
    final hiddenFunctions = _hiddenFunctions;
    if (hiddenFunctions.isEmpty) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.customize.hidden_empty"),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: hiddenFunctions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final entry = hiddenFunctions[index];
              return ListTile(
                leading: Icon(entry.iconData),
                title: Text(FlutterI18n.translate(context, entry.nameKey)),
                trailing: IconButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _addHiddenFunction(entry.id);
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openExternal(String url) async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openScore(BuildContext context) async {
    if (offline && !ScoreSession.isCacheExist) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(
          context,
          "homepage.toolbox.score_cannot_reach",
        ),
      );
      return;
    }
    await context.pushReplacement(const ScoreWindow());
  }

  Future<void> _openExam(BuildContext context) async {
    final controller = Get.find<ExamController>();
    if (controller.status == ExamStatus.cache ||
        controller.status == ExamStatus.fetched) {
      await context.pushReplacement(ExamInfoWindow(time: updateTime));
      return;
    }
    if (controller.status != ExamStatus.error) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.toolbox.exam_fetching"),
      );
      return;
    }
    if (offline) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.offline_mode"),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          FlutterI18n.translate(context, controller.error.toString()).substring(
            0,
            min(
              FlutterI18n.translate(
                context,
                controller.error.toString(),
              ).length,
              120,
            ),
          ),
        ),
      ),
    );
    showToast(
      context: context,
      msg: FlutterI18n.translate(context, "homepage.toolbox.exam_error"),
    );
  }

  Future<void> _openEmptyClassroom(BuildContext context) async {
    if (offline) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.offline_mode"),
      );
      return;
    }
    await context.pushReplacement(const EmptyClassroomWindow());
  }

  Future<void> _openClassAttendance(BuildContext context) async {
    if (offline) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "homepage.offline_mode"),
      );
      return;
    }
    await context.pushReplacement(const ClassAttendanceView());
  }

  Future<void> _openExperiment(BuildContext context) async {
    await context.pushReplacement(const ExperimentWindow());
  }

  Future<void> _openSport(BuildContext context) async {
    var isGood = true;
    if (prefs.getString(prefs.Preference.sportPassword).isEmpty) {
      isGood =
          await showDialog<bool>(
            context: context,
            builder: (context) => const SportPasswordDialog(),
          ) ??
          false;
    }
    if (context.mounted && isGood) {
      await context.pushReplacement(const SportWindow());
    }
  }

  Future<void> _openDormWater(BuildContext context) async {
    await context.pushReplacement(const DormWaterWindow());
  }

  Widget _buildCustomizeTopBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              FlutterI18n.translate(context, "homepage.customize.title"),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: FlutterI18n.translate(context, "homepage.customize.add"),
            onPressed: _showAddHiddenFunctionsSheet,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          TextButton(
            onPressed: _exitCustomizeMode,
            child: Text(
              FlutterI18n.translate(context, "homepage.customize.done"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard(_HomeFunctionEntry entry) {
    return SmallFunctionCard(
      icon: entry.iconData,
      nameKey: entry.nameKey,
      onPressed: _isCustomizing ? null : () => entry.onTap(context),
      onLongPress: _isCustomizing ? null : _enterCustomizeMode,
      topRightAction: _isCustomizing
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _hideFunction(entry.id),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildReorderableCard(_HomeFunctionEntry entry) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != entry.id,
      onAcceptWithDetails: (details) => _moveFunction(details.data, entry.id),
      builder: (context, candidates, _) {
        final card = _buildFunctionCard(entry);
        return LongPressDraggable<String>(
          data: entry.id,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 96,
              child: Opacity(opacity: 0.92, child: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: candidates.isEmpty ? 1.0 : 1.04,
            child: card,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            backgroundColor: Colors.white,
            centerTitle: false,
            expandedHeight: 126,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 8,
              ),
              title: GetBuilder<ClassTableController>(
                builder: (c) => Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FlutterI18n.translate(context, _now),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? null
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      c.state == ClassTableState.fetched
                          ? c.getCurrentWeek(updateTime) >= 0 &&
                                    c.getCurrentWeek(updateTime) <
                                        c.classTableData.semesterLength
                                ? FlutterI18n.translate(
                                    context,
                                    "homepage.on_weekday",
                                    translationParams: {
                                      "current":
                                          "${c.getCurrentWeek(updateTime) + 1}",
                                    },
                                  )
                                : FlutterI18n.translate(
                                    context,
                                    "homepage.on_holiday",
                                  )
                          : c.state == ClassTableState.error
                          ? FlutterI18n.translate(
                              context,
                              "homepage.load_error",
                            )
                          : FlutterI18n.translate(context, "homepage.loading"),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? null
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            showToast(
              context: context,
              msg: FlutterI18n.translate(context, "homepage.loading_message"),
            );
            await update(
              context: context,
              sliderCaptcha: (String cookieStr) {
                return SliderCaptchaClientProvider(
                  cookie: cookieStr,
                ).solve(context);
              },
            );
            if (context.mounted) {
              showToast(
                context: context,
                msg: FlutterI18n.translate(context, "homepage.loaded"),
              );
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            children: [
              const ClassTableCard().padding(bottom: 8),
              ElectricityCard().padding(bottom: 8),
              SchoolnetCard().padding(bottom: 8),
              LibraryCard().padding(bottom: 8),
              SchoolCardInfoCard().padding(bottom: 8),
              if (_isCustomizing) _buildCustomizeTopBar(),
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: GridView.extent(
                  maxCrossAxisExtent: 96,
                  shrinkWrap: true,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _isCustomizing
                      ? _visibleFunctions
                            .map(_buildReorderableCard)
                            .toList(growable: false)
                      : _visibleFunctions
                            .map(_buildFunctionCard)
                            .toList(growable: false),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
