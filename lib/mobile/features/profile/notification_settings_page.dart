import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
          ? const Center(
              child: CircularProgressIndicator(color: MobileTheme.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: MobileTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: MobileTheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MobileTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      _buildSwitchTile(
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
                      _buildDivider(colors),
                      _buildSwitchTile(
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
                      _buildDivider(colors),
                      _buildSwitchTile(
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
                      _buildDivider(colors),
                      _buildSwitchTile(
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
                      _buildDivider(colors),
                      _buildSwitchTile(
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
                      _buildDivider(colors),
                      _buildSwitchTile(
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
                ),
              ],
            ),
    );
  }

  Widget _buildDivider(MobileColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, thickness: 0.5, color: colors.divider),
    );
  }

  Widget _buildSwitchTile({
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
      activeThumbColor: MobileTheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}
