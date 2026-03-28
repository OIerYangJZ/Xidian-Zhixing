import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/state/mobile_providers.dart';

/// 设置主页 — Instagram 风格
/// 账号安全 / 隐私设置 / 通知 / 关于 / 退出登录
class SettingsMainPage extends ConsumerStatefulWidget {
  const SettingsMainPage({super.key});

  @override
  ConsumerState<SettingsMainPage> createState() => _SettingsMainPageState();
}

class _SettingsMainPageState extends ConsumerState<SettingsMainPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updatePrivacy(
            allowStrangerDm: allowStrangerDm,
            showContactable: showContactable,
          );
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(
          allowStrangerDm: allowStrangerDm,
          showContactable: showContactable,
        );
      });
      _showToast('隐私设置已更新');
    } catch (e) {
      _showToast('设置失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {}

    AuthStore.instance.clear();
    if (!mounted) return;
    context.go('/auth/login');
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('该功能正在开发中，敬请期待。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.background,
      appBar: AppBar(
        backgroundColor: MobileTheme.surface,
        scrolledUnderElevation: 0.5,
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MobileTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MobileTheme.primary))
          : ListView(
              children: [
                const SizedBox(height: 8),

                // 账号安全区
                _SectionHeader(title: '账号安全'),
                _ListCard(
                  children: [
                    _ListTile(
                      icon: Icons.lock_reset_outlined,
                      iconColor: MobileTheme.primary,
                      title: '修改密码',
                      onTap: () => context.push('/profile/change-password'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.edit_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '编辑资料',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.no_accounts_outlined,
                      iconColor: MobileTheme.error,
                      title: '注销账号',
                      titleColor: MobileTheme.error,
                      onTap: () => _showCancelAccountHint(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 隐私设置区
                _SectionHeader(title: '隐私设置'),
                _ListCard(
                  children: [
                    _SwitchTileRow(
                      icon: Icons.chat_bubble_outline,
                      iconColor: MobileTheme.primary,
                      title: '允许陌生人私信',
                      subtitle: '关闭后，其他人无法通过你的公开主页或帖子给你发起私信',
                      value: _profile?.allowStrangerDm ?? false,
                      onChanged: _saving
                          ? null
                          : (value) => _updatePrivacy(
                                allowStrangerDm: value,
                                showContactable:
                                    _profile?.showContactable ?? false,
                              ),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _SwitchTileRow(
                      icon: Icons.visibility_outlined,
                      iconColor: MobileTheme.accent,
                      title: '显示"可联系"状态',
                      subtitle: '开启后其他人可见联系方式',
                      value: _profile?.showContactable ?? false,
                      onChanged: _saving
                          ? null
                          : (value) => _updatePrivacy(
                                allowStrangerDm:
                                    _profile?.allowStrangerDm ?? false,
                                showContactable: value,
                              ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 通知区
                _SectionHeader(title: '通知'),
                _ListCard(
                  children: [
                    _ListTile(
                      icon: Icons.notifications_outlined,
                      iconColor: MobileTheme.primary,
                      title: '通知设置',
                      onTap: () => _showComingSoonDialog('通知设置'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.vibration_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '声音与振动',
                      onTap: () => _showComingSoonDialog('声音与振动'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 关于区
                _SectionHeader(title: '关于'),
                _ListCard(
                  children: [
                    _ListTile(
                      icon: Icons.description_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '用户协议',
                      onTap: () => context.push('/legal/terms'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '隐私政策',
                      onTap: () => context.push('/legal/privacy'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.gavel_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '社区规范',
                      onTap: () => context.push('/legal/guidelines'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.flag_outlined,
                      iconColor: MobileTheme.textSecondary,
                      title: '举报说明',
                      onTap: () => context.push('/legal/report'),
                    ),
                    const Divider(
                        height: 0.5, indent: 56, color: MobileTheme.divider),
                    _ListTile(
                      icon: Icons.help_outline,
                      iconColor: MobileTheme.textSecondary,
                      title: '帮助与反馈',
                      onTap: () => context.push('/profile/help-feedback'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 应用信息区
                _SectionHeader(title: '应用信息'),
                _ListCard(
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 22, color: MobileTheme.textSecondary),
                          SizedBox(width: 14),
                          Text(
                            '版本号',
                            style: TextStyle(
                              fontSize: 15,
                              color: MobileTheme.textPrimary,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: MobileTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 退出登录（全宽红色文字）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: MobileTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '退出登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MobileTheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showCancelAccountHint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '账号注销后将永久删除所有数据，且无法恢复。\n\n确认要注销账号吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showCancelAccountPassword();
            },
            child: const Text('继续注销'),
          ),
        ],
      ),
    );
  }

  void _showCancelAccountPassword() {
    final passwordController = TextEditingController();
    bool obscure = true;
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('验证身份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请输入当前登录密码以确认注销申请：', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: '当前密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
              onPressed: submitting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        // 用密码验证身份（调用登录接口）
                        final email = AuthStore
                                    .instance.currentUser?.studentId !=
                                null
                            ? '${AuthStore.instance.currentUser!.studentId}@stu.xidian.edu.cn'
                            : '';
                        await ref.read(authRepositoryProvider).login(
                              identifier: email,
                              password: passwordController.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _submitCancellationRequest();
                      } catch (_) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('密码错误，请重新输入')),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认注销'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCancellationRequest() async {
    try {
      await ref
          .read(userRepositoryProvider)
          .submitAccountCancellationRequest(reason: '用户主动申请注销');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('申请已提交'),
          content: const Text(
            '注销申请已提交给管理员审核。审核通过后，账号和所有数据将被永久删除。\n\n审核结果将通过邮件通知您。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _logout();
              },
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showToast('申请提交失败，请稍后重试');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MobileTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final List<Widget> children;

  const _ListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MobileTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? MobileTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: MobileTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SwitchTileRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTileRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: MobileTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MobileTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: MobileTheme.primary,
          ),
        ],
      ),
    );
  }
}
