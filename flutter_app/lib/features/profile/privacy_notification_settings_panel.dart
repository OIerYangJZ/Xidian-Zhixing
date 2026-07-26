import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';

class PrivacyNotificationSettingsPanel extends StatefulWidget {
  const PrivacyNotificationSettingsPanel({super.key});

  @override
  State<PrivacyNotificationSettingsPanel> createState() =>
      _PrivacyNotificationSettingsPanelState();
}

class _PrivacyNotificationSettingsPanelState
    extends State<PrivacyNotificationSettingsPanel> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final UserProfile profile = await AppRepositories.users.fetchProfile();
      if (!mounted) return;
      AuthStore.instance.setCurrentUser(profile);
      setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = '资料加载失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppStatePanel(
        icon: Icons.shield_outlined,
        title: '正在加载隐私与通知',
        message: '正在读取设置。',
      );
    }
    final UserProfile? profile = _profile;
    if (profile == null) {
      return AppStatePanel(
        icon: Icons.error_outline_rounded,
        title: '隐私与通知加载失败',
        message: _error ?? '设置暂时不可用。',
        action: FilledButton(onPressed: _loadProfile, child: const Text('重试')),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxxl,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text('隐私与通知', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xxl),
            Text('隐私', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _PrivacyToggleRow(
              icon: Icons.forum_outlined,
              title: '允许陌生人私信',
              value: profile.allowStrangerDm,
              onChanged: _saving
                  ? null
                  : (bool value) => _updatePrivacy(
                      allowStrangerDm: value,
                      showContactable: profile.showContactable,
                    ),
            ),
            const Divider(height: 1, indent: 64),
            _PrivacyToggleRow(
              icon: Icons.person_outline_rounded,
              title: '显示可联系状态',
              value: profile.showContactable,
              onChanged: _saving
                  ? null
                  : (bool value) => _updatePrivacy(
                      allowStrangerDm: profile.allowStrangerDm,
                      showContactable: value,
                    ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('通知', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _PrivacyToggleRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: '评论与回复',
              value: profile.notifyComment && profile.notifyReply,
              onChanged: _saving
                  ? null
                  : (bool value) => _updateNotifications(
                      profile,
                      notifyComment: value,
                      notifyReply: value,
                    ),
            ),
            const Divider(height: 1, indent: 64),
            _PrivacyToggleRow(
              icon: Icons.favorite_border_rounded,
              title: '点赞与收藏',
              value: profile.notifyLike && profile.notifyFavorite,
              onChanged: _saving
                  ? null
                  : (bool value) => _updateNotifications(
                      profile,
                      notifyLike: value,
                      notifyFavorite: value,
                    ),
            ),
            const Divider(height: 1, indent: 64),
            _PrivacyToggleRow(
              icon: Icons.notifications_none_rounded,
              title: '系统通知',
              value: profile.notifySystem,
              onChanged: _saving
                  ? null
                  : (bool value) =>
                        _updateNotifications(profile, notifySystem: value),
            ),
            const Divider(height: 1, indent: 64),
            _PrivacyToggleRow(
              icon: Icons.flag_outlined,
              title: '举报处理结果',
              value: profile.notifyReportResult,
              onChanged: _saving
                  ? null
                  : (bool value) => _updateNotifications(
                      profile,
                      notifyReportResult: value,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    final UserProfile? profile = _profile;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await AppRepositories.users.updatePrivacy(
        allowStrangerDm: allowStrangerDm,
        showContactable: showContactable,
      );
      if (!mounted) return;
      final UserProfile updated = profile.copyWith(
        allowStrangerDm: allowStrangerDm,
        showContactable: showContactable,
      );
      AuthStore.instance.setCurrentUser(updated);
      setState(() => _profile = updated);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateNotifications(
    UserProfile profile, {
    bool? notifyComment,
    bool? notifyReply,
    bool? notifyLike,
    bool? notifyFavorite,
    bool? notifyReportResult,
    bool? notifySystem,
  }) async {
    final UserProfile updated = profile.copyWith(
      notifyComment: notifyComment,
      notifyReply: notifyReply,
      notifyLike: notifyLike,
      notifyFavorite: notifyFavorite,
      notifyReportResult: notifyReportResult,
      notifySystem: notifySystem,
    );
    setState(() => _saving = true);
    try {
      await AppRepositories.users.updateNotificationPreferences(
        notifyComment: updated.notifyComment,
        notifyReply: updated.notifyReply,
        notifyLike: updated.notifyLike,
        notifyFavorite: updated.notifyFavorite,
        notifyReportResult: updated.notifyReportResult,
        notifySystem: updated.notifySystem,
      );
      if (!mounted) return;
      AuthStore.instance.setCurrentUser(updated);
      setState(() => _profile = updated);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Material(
      color: colors.page.withValues(alpha: 0),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(AppRadii.hero),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(icon, size: 20, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
