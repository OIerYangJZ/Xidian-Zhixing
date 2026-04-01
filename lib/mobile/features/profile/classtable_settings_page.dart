import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/experiment_controller.dart';
import 'package:watermeter/page/homepage/refresh.dart' as wm_refresh;
import 'package:watermeter/page/setting/dialogs/change_swift_dialog.dart';
import 'package:watermeter/page/setting/dialogs/semester_switch_dialog.dart';
import 'package:watermeter/repository/network_session.dart';
import 'package:watermeter/repository/pick_file.dart';
import 'package:watermeter/repository/preference.dart' as wm_preference;
import 'package:watermeter/repository/xidian_ids/classtable_session.dart';

import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class ClasstableSettingsPage extends StatefulWidget {
  const ClasstableSettingsPage({super.key});

  @override
  State<ClasstableSettingsPage> createState() => _ClasstableSettingsPageState();
}

class _ClasstableSettingsPageState extends State<ClasstableSettingsPage> {
  bool _decorated = wm_preference.getBool(wm_preference.Preference.decorated);
  bool _busy = false;

  ClassTableController _classTableController() {
    if (Get.isRegistered<ClassTableController>()) {
      return Get.find<ClassTableController>();
    }
    return Get.put(ClassTableController());
  }

  ExamController _examController() {
    if (Get.isRegistered<ExamController>()) {
      return Get.find<ExamController>();
    }
    return Get.put(ExamController());
  }

  ExperimentController _experimentController() {
    if (Get.isRegistered<ExperimentController>()) {
      return Get.find<ExperimentController>();
    }
    return Get.put(ExperimentController());
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleDecorated(bool value) async {
    if (value && !wm_preference.getBool(wm_preference.Preference.decoration)) {
      _showToast('请先选择课表背景图片');
      return;
    }
    await wm_preference.setBool(wm_preference.Preference.decorated, value);
    if (!mounted) {
      return;
    }
    setState(() => _decorated = value);
  }

  Future<void> _pickBackground() async {
    try {
      final FilePickerResult? result = await pickFile(type: FileType.image);
      if (result == null || result.files.single.path == null) {
        _showToast('未选择图片');
        return;
      }
      File(
        result.files.single.path!,
      ).copySync('${supportPath.path}/${ClassTableFile.decorationName}');
      await wm_preference.setBool(wm_preference.Preference.decoration, true);
      _showToast('背景图片已更新');
    } on MissingStoragePermissionException {
      _showToast('缺少文件读取权限，请在系统设置中授权');
    } catch (error) {
      _showToast('设置背景失败：$error');
    }
  }

  Future<void> _clearUserClasses() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空自定义课程'),
        content: const Text('确认删除所有手动添加的课程吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final File file = File(
      '${supportPath.path}/${ClassTableFile.userDefinedClassName}',
    );
    if (file.existsSync()) {
      file.deleteSync();
    }
    await _classTableController().updateClassTable(isUserDefinedChanged: true);
    wm_refresh.updateCurrentData();
    _showToast('已清空自定义课程');
  }

  Future<void> _refreshClasstableData() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Future.wait([
        _classTableController().updateClassTable(isForce: true),
        _examController().get(),
        _experimentController().get(),
      ]);
      wm_refresh.updateCurrentData();
      _showToast('课表相关数据已刷新');
    } catch (error) {
      _showToast('刷新失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openChangeWeekOffsetDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeSwiftDialog(),
    );
    _classTableController().update();
    wm_refresh.updateCurrentData();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openSemesterSwitchDialog() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SemesterSwitchDialog(),
    );
    if (changed != true) {
      return;
    }
    await _classTableController().updateClassTable(isForce: true);
    await _examController().get();
    wm_refresh.updateCurrentData();
    if (!mounted) {
      return;
    }
    setState(() {});
    _showToast('学期配置已更新');
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final String weekOffset = wm_preference
        .getInt(wm_preference.Preference.swift)
        .toString();
    final String semesterCode = wm_preference.getString(
      wm_preference.Preference.currentSemester,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('课表设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: '课表相关'),
          _ListCard(
            children: [
              _SwitchRow(
                icon: Icons.wallpaper_outlined,
                iconColor: colors.textSecondary,
                title: '课表背景',
                subtitle: '开启后课表页使用自定义背景',
                value: _decorated,
                onChanged: _toggleDecorated,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.image_outlined,
                iconColor: colors.textSecondary,
                title: '选择背景图片',
                subtitle: '从相册选择课表背景',
                onTap: _pickBackground,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.delete_sweep_outlined,
                iconColor: MobileTheme.error,
                title: '清空自定义课程',
                subtitle: '删除手动添加的课程',
                onTap: _clearUserClasses,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.sync_outlined,
                iconColor: MobileTheme.primaryOf(context),
                title: '刷新课表数据',
                subtitle: '重新拉取课表、考试与实验数据',
                trailing: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MobileTheme.primaryOf(context),
                        ),
                      )
                    : null,
                onTap: _busy ? null : _refreshClasstableData,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.swap_vert_outlined,
                iconColor: colors.textSecondary,
                title: '周次偏移',
                subtitle: '当前偏移：$weekOffset 周',
                onTap: _openChangeWeekOffsetDialog,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.event_outlined,
                iconColor: colors.textSecondary,
                title: '学期切换',
                subtitle: semesterCode.isEmpty
                    ? '当前学期：未设置'
                    : '当前学期：$semesterCode',
                onTap: _openSemesterSwitchDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: onTap == null
                      ? colors.textTertiary.withValues(alpha: 0.5)
                      : colors.textTertiary,
                ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MobileTheme.primaryOf(context),
          ),
        ],
      ),
    );
  }
}
