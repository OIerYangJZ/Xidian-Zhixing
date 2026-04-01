import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/experiment_controller.dart';
import 'package:watermeter/repository/notification/course_reminder_service.dart';

import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';
import '../../integrations/xdyou_bootstrap.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

const kDefaultMinutesBeforeOptions = [5, 10, 15, 20, 30];
const kDefaultDaysToScheduleOptions = [3, 7, 14, 30];

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  final CourseReminderService _courseReminder = CourseReminderService();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _courseReady = false;
  bool _courseBusy = false;
  String? _courseError;
  bool _courseEnabled = false;
  bool _experimentReminderEnabled = false;
  bool _hasNotificationPermission = false;
  bool _hasExactAlarmPermission = false;
  int _minutesBefore = 5;
  int _daysToSchedule = 7;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    setState(() {
      _loading = true;
      _error = null;
      _courseError = null;
    });
    await Future.wait([_loadProfile(), _loadCourseReminderSettings()]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final UserProfile profile = await ref
          .read(userRepositoryProvider)
          .fetchProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadCourseReminderSettings() async {
    try {
      await ensureXdyouEmbedInitialized();
      if (!Get.isRegistered<ClassTableController>()) {
        Get.put(ClassTableController());
      }
      if (!Get.isRegistered<ExamController>()) {
        Get.put(ExamController());
      }
      if (!Get.isRegistered<ExperimentController>()) {
        Get.put(ExperimentController());
      }

      await _courseReminder.initialize();

      _courseEnabled = _courseReminder.isEnabled;
      _experimentReminderEnabled =
          _courseReminder.enableExperimentNotifications;
      _minutesBefore = _courseReminder.minutesBefore;
      _daysToSchedule = _courseReminder.daysToSchedule;
      if (!kDefaultMinutesBeforeOptions.contains(_minutesBefore)) {
        _minutesBefore = kDefaultMinutesBeforeOptions.first;
      }
      if (!kDefaultDaysToScheduleOptions.contains(_daysToSchedule)) {
        _daysToSchedule = kDefaultDaysToScheduleOptions[1];
      }

      _hasNotificationPermission = await _courseReminder
          .checkNotificationPermission();
      _hasExactAlarmPermission = await _courseReminder
          .checkExactAlarmPermission();
      if ((!_hasNotificationPermission || !_hasExactAlarmPermission) &&
          _courseEnabled) {
        await _courseReminder.setEnabled(false);
        _courseEnabled = false;
      }
      _pendingCount = await _courseReminder
          .getPendingCourseNotificationsCount();
      _courseReady = true;
    } catch (error) {
      _courseError = error.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _updateNotificationPreferences({
    bool? notifyComment,
    bool? notifyReply,
    bool? notifyLike,
    bool? notifyFavorite,
    bool? notifyReportResult,
    bool? notifySystem,
  }) async {
    final UserProfile? current = _profile;
    if (current == null) return;

    final UserProfile next = current.copyWith(
      notifyComment: notifyComment ?? current.notifyComment,
      notifyReply: notifyReply ?? current.notifyReply,
      notifyLike: notifyLike ?? current.notifyLike,
      notifyFavorite: notifyFavorite ?? current.notifyFavorite,
      notifyReportResult: notifyReportResult ?? current.notifyReportResult,
      notifySystem: notifySystem ?? current.notifySystem,
    );

    setState(() {
      _saving = true;
      _profile = next;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .updateNotificationPreferences(
            notifyComment: next.notifyComment,
            notifyReply: next.notifyReply,
            notifyLike: next.notifyLike,
            notifyFavorite: next.notifyFavorite,
            notifyReportResult: next.notifyReportResult,
            notifySystem: next.notifySystem,
          );
      _showToast('通知设置已更新');
    } catch (error) {
      if (!mounted) return;
      setState(() => _profile = current);
      _showToast('设置失败：${error.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _requestCoursePermissions() async {
    if (_courseBusy) return;
    setState(() => _courseBusy = true);
    try {
      final bool notificationGranted = await _courseReminder
          .requestNotificationPermission();
      final bool exactAlarmGranted = await _courseReminder
          .requestExactAlarmPermission();
      if (!mounted) return;
      setState(() {
        _hasNotificationPermission = notificationGranted;
        _hasExactAlarmPermission = exactAlarmGranted;
      });
      if (notificationGranted && exactAlarmGranted) {
        _showToast('课前提醒权限已就绪');
      } else {
        _showToast('仍缺少权限，请在系统设置中开启通知与精确闹钟');
      }
    } catch (error) {
      _showToast('权限申请失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _toggleCourseReminder(bool value) async {
    if (_courseBusy) return;
    try {
      if (value) {
        if (!_hasNotificationPermission || !_hasExactAlarmPermission) {
          await _requestCoursePermissions();
        }
        if (!_hasNotificationPermission || !_hasExactAlarmPermission) {
          return;
        }
        final controller = Get.find<ClassTableController>();
        if (controller.classTableData.termStartDay.isEmpty) {
          _showToast('暂无课表数据，请先进入校园页拉取课表');
          return;
        }
      }
      if (mounted) {
        setState(() => _courseBusy = true);
      }
      await _courseReminder.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _courseEnabled = value;
      });
      if (value) {
        _pendingCount = await _courseReminder
            .getPendingCourseNotificationsCount();
        _showToast('课前提醒已开启，已安排 $_pendingCount 条提醒');
      } else {
        _pendingCount = 0;
        _showToast('课前提醒已关闭');
      }
    } catch (error) {
      _showToast('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _toggleExperimentReminder(bool value) async {
    if (_courseBusy) return;
    setState(() {
      _courseBusy = true;
      _experimentReminderEnabled = value;
    });
    try {
      await _courseReminder.setEnableExperimentNotifications(value);
      if (_courseEnabled) {
        _pendingCount = await _courseReminder
            .getPendingCourseNotificationsCount();
      }
      _showToast(value ? '已开启实验课提醒' : '已关闭实验课提醒');
    } catch (error) {
      if (mounted) {
        setState(() => _experimentReminderEnabled = !value);
      }
      _showToast('设置失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _changeMinutesBefore(int value) async {
    if (_courseBusy) return;
    setState(() {
      _courseBusy = true;
      _minutesBefore = value;
    });
    try {
      await _courseReminder.setMinutesBefore(value);
      if (_courseEnabled) {
        _pendingCount = await _courseReminder
            .getPendingCourseNotificationsCount();
      }
      _showToast('提醒时间已更新');
    } catch (error) {
      _showToast('设置失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _changeDaysToSchedule(int value) async {
    if (_courseBusy) return;
    setState(() {
      _courseBusy = true;
      _daysToSchedule = value;
    });
    try {
      await _courseReminder.setDaysToSchedule(value);
      if (_courseEnabled) {
        _pendingCount = await _courseReminder
            .getPendingCourseNotificationsCount();
      }
      _showToast('预排天数已更新');
    } catch (error) {
      _showToast('设置失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _rescheduleCourseReminders() async {
    if (_courseBusy || !_courseEnabled) return;
    setState(() => _courseBusy = true);
    try {
      await _courseReminder.cancelAllCourseNotifications();
      await _courseReminder.scheduleNotificationsFromCourseData(
        daysToSchedule: _daysToSchedule,
        minutesBefore: _minutesBefore,
      );
      _pendingCount = await _courseReminder
          .getPendingCourseNotificationsCount();
      _showToast('提醒已重排，共 $_pendingCount 条');
    } catch (error) {
      _showToast('重排失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  Future<void> _clearCourseReminders() async {
    if (_courseBusy || _pendingCount == 0) return;
    setState(() => _courseBusy = true);
    try {
      await _courseReminder.cancelAllCourseNotifications();
      if (mounted) {
        setState(() => _pendingCount = 0);
      }
      _showToast('已清空全部课前提醒');
    } catch (error) {
      _showToast('清空失败：$error');
    } finally {
      if (mounted) {
        setState(() => _courseBusy = false);
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('通知设置'),
        backgroundColor: colors.surface,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null)
                  _ErrorBanner(message: _error!, colors: colors),
                _SectionCard(
                  title: '树洞通知',
                  children: <Widget>[
                    _buildTreeholeSwitch(
                      icon: Icons.comment_outlined,
                      title: '评论通知',
                      subtitle: '有人评论你的帖子时提醒你',
                      value: _profile?.notifyComment ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifyComment: value,
                            ),
                    ),
                    _buildTreeholeSwitch(
                      icon: Icons.reply_outlined,
                      title: '回复通知',
                      subtitle: '有人回复你的评论时提醒你',
                      value: _profile?.notifyReply ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifyReply: value,
                            ),
                    ),
                    _buildTreeholeSwitch(
                      icon: Icons.thumb_up_alt_outlined,
                      title: '点赞通知',
                      subtitle: '你的帖子或评论被点赞时提醒你',
                      value: _profile?.notifyLike ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifyLike: value,
                            ),
                    ),
                    _buildTreeholeSwitch(
                      icon: Icons.bookmark_outline,
                      title: '收藏通知',
                      subtitle: '你的帖子被收藏时提醒你',
                      value: _profile?.notifyFavorite ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifyFavorite: value,
                            ),
                    ),
                    _buildTreeholeSwitch(
                      icon: Icons.flag_outlined,
                      title: '举报结果通知',
                      subtitle: '你发起的举报有处理结果时提醒你',
                      value: _profile?.notifyReportResult ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifyReportResult: value,
                            ),
                    ),
                    _buildTreeholeSwitch(
                      icon: Icons.campaign_outlined,
                      title: '系统通知与公告',
                      subtitle: '包括系统消息、公告和管理员处理结果',
                      value: _profile?.notifySystem ?? true,
                      onChanged: _saving
                          ? null
                          : (value) => _updateNotificationPreferences(
                              notifySystem: value,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '课前通知（校园）',
                  children: [
                    if (_courseError != null)
                      ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: MobileTheme.error,
                        ),
                        title: const Text('校园提醒初始化失败'),
                        subtitle: Text(_courseError!),
                        trailing: TextButton(
                          onPressed: _loadCourseReminderSettings,
                          child: const Text('重试'),
                        ),
                      )
                    else ...[
                      SwitchListTile(
                        value: _courseEnabled,
                        onChanged: !_courseReady || _courseBusy
                            ? null
                            : _toggleCourseReminder,
                        secondary: Icon(
                          Icons.alarm_on_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('开启课前提醒'),
                        subtitle: Text(
                          _courseEnabled
                              ? '已安排 $_pendingCount 条提醒'
                              : '关闭后不会推送课程与实验提醒',
                        ),
                        activeThumbColor: MobileTheme.primaryOf(context),
                      ),
                      _divider(colors),
                      SwitchListTile(
                        value: _experimentReminderEnabled,
                        onChanged: !_courseReady || _courseBusy
                            ? null
                            : _toggleExperimentReminder,
                        secondary: Icon(
                          Icons.science_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('实验课提醒'),
                        subtitle: const Text('开启后实验课也会生成课前通知'),
                        activeThumbColor: MobileTheme.primaryOf(context),
                      ),
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          Icons.schedule_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('提前提醒时间'),
                        subtitle: const Text('上课前多久发送提醒'),
                        trailing: DropdownButton<int>(
                          value: _minutesBefore,
                          items: kDefaultMinutesBeforeOptions
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value 分钟'),
                                ),
                              )
                              .toList(),
                          onChanged: !_courseReady || _courseBusy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _changeMinutesBefore(value);
                                  }
                                },
                        ),
                      ),
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          Icons.date_range_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('预排提醒天数'),
                        subtitle: const Text('提前生成未来多少天的提醒'),
                        trailing: DropdownButton<int>(
                          value: _daysToSchedule,
                          items: kDefaultDaysToScheduleOptions
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value 天'),
                                ),
                              )
                              .toList(),
                          onChanged: !_courseReady || _courseBusy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _changeDaysToSchedule(value);
                                  }
                                },
                        ),
                      ),
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          Icons.refresh_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('重排提醒'),
                        subtitle: const Text('按当前参数重新生成全部提醒'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: !_courseReady || _courseBusy || !_courseEnabled
                            ? null
                            : _rescheduleCourseReminders,
                      ),
                      if (_pendingCount > 0) ...[
                        _divider(colors),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: MobileTheme.error,
                          ),
                          title: const Text('清空提醒'),
                          subtitle: const Text('删除全部已安排的课前提醒'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _courseBusy ? null : _clearCourseReminders,
                        ),
                      ],
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          _hasNotificationPermission
                              ? Icons.check_circle_outline
                              : Icons.notifications_off_outlined,
                          color: _hasNotificationPermission
                              ? MobileTheme.primaryOf(context)
                              : colors.textSecondary,
                        ),
                        title: const Text('通知权限'),
                        subtitle: Text(
                          _hasNotificationPermission ? '已授予' : '未授予',
                        ),
                        trailing: _hasNotificationPermission
                            ? null
                            : TextButton(
                                onPressed: _courseBusy
                                    ? null
                                    : _requestCoursePermissions,
                                child: const Text('申请'),
                              ),
                      ),
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          _hasExactAlarmPermission
                              ? Icons.check_circle_outline
                              : Icons.alarm_off_outlined,
                          color: _hasExactAlarmPermission
                              ? MobileTheme.primaryOf(context)
                              : colors.textSecondary,
                        ),
                        title: const Text('精确闹钟权限'),
                        subtitle: Text(
                          _hasExactAlarmPermission ? '已授予' : '未授予',
                        ),
                        trailing: _hasExactAlarmPermission
                            ? null
                            : TextButton(
                                onPressed: _courseBusy
                                    ? null
                                    : _requestCoursePermissions,
                                child: const Text('申请'),
                              ),
                      ),
                      _divider(colors),
                      ListTile(
                        leading: Icon(
                          Icons.settings_outlined,
                          color: colors.textSecondary,
                        ),
                        title: const Text('打开系统通知设置'),
                        subtitle: const Text('前往系统页面检查通知与电池策略'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _courseBusy
                            ? null
                            : _courseReminder.openNotificationSettings,
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildTreeholeSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colors = MobileColors.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: colors.textSecondary),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colors.textSecondary,
          height: 1.4,
        ),
      ),
      activeThumbColor: MobileTheme.primaryOf(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Widget _divider(MobileColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, thickness: 0.5, color: colors.divider),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.colors});

  final String message;
  final MobileColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MobileTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: MobileTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: MobileTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
