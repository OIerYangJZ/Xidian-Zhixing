import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class AccountSecurityPage extends ConsumerStatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  ConsumerState<AccountSecurityPage> createState() =>
      _AccountSecurityPageState();
}

class _AccountSecurityPageState extends ConsumerState<AccountSecurityPage> {
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
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _promptLevelUpgradeRequest() async {
    final profile = _profile;
    if (profile == null || profile.isLevelOneUser) return;
    final request = profile.levelUpgradeRequest;
    if (request?.status == 'pending') {
      _showToast('你已经提交过申请了，请等待管理员审核');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('申请成为一级用户'),
        content: const Text('确认提交一级用户申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).submitLevelUpgradeRequest();
      await _loadProfile();
      _showToast('一级用户申请已提交');
    } catch (e) {
      _showToast('提交失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _levelUpgradeSubtitle(UserLevelRequestSummary? request) {
    if (request == null) return '当前为二级用户，可申请升级为一级用户';
    final buffer = StringBuffer(
      '${request.statusLabel} · ${request.createdAt}',
    );
    if (request.adminNote.trim().isNotEmpty) {
      buffer.write(' · ${request.adminNote.trim()}');
    }
    return buffer.toString();
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
        title: const Text('账号安全'),
        backgroundColor: colors.background,
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : _profile == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 42,
                    color: MobileTheme.error,
                  ),
                  const SizedBox(height: 10),
                  Text(_error ?? '账号信息加载失败'),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _loadProfile, child: const Text('重试')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTileCard([
                  if (!(_profile?.isLevelOneUser ?? false))
                    _buildListTile(
                      icon: Icons.workspace_premium_outlined,
                      title: '申请成为一级用户',
                      subtitle: _levelUpgradeSubtitle(
                        _profile?.levelUpgradeRequest,
                      ),
                      onTap:
                          _saving ||
                              _profile?.levelUpgradeRequest?.status == 'pending'
                          ? null
                          : _promptLevelUpgradeRequest,
                    ),
                ]),
              ],
            ),
    );
  }

  Widget _buildTileCard(List<Widget> children) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        children: List<Widget>.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(height: 0.5, indent: 56, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? titleColor,
  }) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: titleColor ?? colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

}
