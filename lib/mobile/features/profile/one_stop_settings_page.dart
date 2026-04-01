import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watermeter/page/setting/dialogs/electricity_account_dialog.dart';
import 'package:watermeter/page/setting/dialogs/electricity_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/experiment_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/schoolnet_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/sport_password_dialog.dart';
import 'package:watermeter/repository/preference.dart' as wm_preference;
import 'package:watermeter/repository/xidian_ids/electricity_session.dart'
    as electricity_session;
import 'package:watermeter/repository/xidian_ids/personal_info_session.dart';

import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class OneStopSettingsPage extends StatefulWidget {
  const OneStopSettingsPage({super.key});

  @override
  State<OneStopSettingsPage> createState() => _OneStopSettingsPageState();
}

class _OneStopSettingsPageState extends State<OneStopSettingsPage> {
  bool _savingElectricityAccount = false;

  bool get _isPostgraduate =>
      wm_preference.getBool(wm_preference.Preference.role);

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSportPasswordDialog() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => const SportPasswordDialog(),
    );
    if (!mounted || saved != true) {
      return;
    }
    _showToast('体育系统密码已保存');
  }

  Future<void> _openExperimentPasswordDialog() async {
    final String before = wm_preference.getString(
      wm_preference.Preference.experimentPassword,
    );
    await showDialog<void>(
      context: context,
      builder: (_) => const ExperimentPasswordDialog(),
    );
    if (!mounted) {
      return;
    }
    final String after = wm_preference.getString(
      wm_preference.Preference.experimentPassword,
    );
    if (before != after && after.isNotEmpty) {
      _showToast('物理实验密码已保存');
    }
  }

  Future<void> _openElectricityAccountDialog() async {
    if (_savingElectricityAccount) {
      return;
    }
    setState(() => _savingElectricityAccount = true);
    try {
      final bool? saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ElectricityAccountDialog(
          initialAccountNumber: wm_preference.getString(
            wm_preference.Preference.electricityAccount,
          ),
          onSaveAccount: (accountNumber) async {
            await wm_preference.setString(
              wm_preference.Preference.electricityAccount,
              accountNumber,
            );
          },
          onFetchFromNetwork: () async {
            final String dorm = await PersonalInfoSession().getDormInfoEhall();
            return electricity_session
                .ElectricitySession.parseElectricityAccountFromIDS(dorm);
          },
        ),
      );
      if (!mounted || saved != true) {
        return;
      }
      electricity_session.ElectricitySession.clearElectricityHistory();
      unawaited(electricity_session.update(force: true));
      _showToast('电费账号已更新，正在刷新数据');
    } finally {
      if (mounted) {
        setState(() => _savingElectricityAccount = false);
      }
    }
  }

  Future<void> _openElectricityPasswordDialog() async {
    final String before = wm_preference.getString(
      wm_preference.Preference.electricityPassword,
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ElectricityPasswordDialog(),
    );
    if (!mounted) {
      return;
    }
    final String after = wm_preference.getString(
      wm_preference.Preference.electricityPassword,
    );
    if (before != after && after.isNotEmpty) {
      _showToast('电费密码已保存');
    }
  }

  Future<void> _openSchoolnetPasswordDialog() async {
    final String before = wm_preference.getString(
      wm_preference.Preference.schoolNetQueryPassword,
    );
    await showDialog<void>(
      context: context,
      builder: (_) => const SchoolNetPasswordDialog(),
    );
    if (!mounted) {
      return;
    }
    final String after = wm_preference.getString(
      wm_preference.Preference.schoolNetQueryPassword,
    );
    if (before != after && after.isNotEmpty) {
      _showToast('校园网查询密码已保存');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('一站式设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: '账号设置'),
          _ListCard(
            children: [
              if (!_isPostgraduate) ...[
                _ListTile(
                  icon: Icons.fitness_center_outlined,
                  iconColor: colors.textSecondary,
                  title: '体育系统密码',
                  subtitle: '用于体育成绩与体育模块',
                  onTap: _openSportPasswordDialog,
                ),
                Divider(height: 0.5, indent: 56, color: colors.divider),
                _ListTile(
                  icon: Icons.science_outlined,
                  iconColor: colors.textSecondary,
                  title: '物理实验密码',
                  subtitle: '用于实验课相关模块',
                  onTap: _openExperimentPasswordDialog,
                ),
                Divider(height: 0.5, indent: 56, color: colors.divider),
              ],
              _ListTile(
                icon: Icons.bolt_outlined,
                iconColor: MobileTheme.warning,
                title: '电费账号',
                subtitle: '支持手动输入和从校园系统自动获取',
                trailing: _savingElectricityAccount
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MobileTheme.primaryOf(context),
                        ),
                      )
                    : null,
                onTap: _savingElectricityAccount
                    ? null
                    : _openElectricityAccountDialog,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.lock_outline,
                iconColor: colors.textSecondary,
                title: '电费密码',
                subtitle: '用于电费系统登录',
                onTap: _openElectricityPasswordDialog,
              ),
              Divider(height: 0.5, indent: 56, color: colors.divider),
              _ListTile(
                icon: Icons.wifi_outlined,
                iconColor: colors.textSecondary,
                title: '校园网查询密码',
                subtitle: '用于校园网使用信息查询',
                onTap: _openSchoolnetPasswordDialog,
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
