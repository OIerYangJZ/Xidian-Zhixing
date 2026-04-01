import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
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
      await ref
          .read(userRepositoryProvider)
          .updatePrivacy(
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

  Future<void> _promptLevelUpgradeRequest() async {
    final profile = _profile;
    if (profile == null || profile.isLevelOneUser) return;
    final currentRequest = profile.levelUpgradeRequest;
    if (currentRequest?.status == 'pending') {
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _levelUpgradeSubtitle(UserLevelRequestSummary? request) {
    if (request == null) {
      return '当前为二级用户，可申请升级为一级用户';
    }
    final buffer = StringBuffer(
      '${request.statusLabel} · ${request.createdAt}',
    );
    if (request.adminNote.trim().isNotEmpty) {
      buffer.write(' · ${request.adminNote.trim()}');
    }
    return buffer.toString();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0.5,
        title: Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MobileTheme.primary),
            )
          : ListView(
              children: [
                const SizedBox(height: 8),

                // 账号安全区
                if (!(_profile?.isLevelOneUser ?? false)) ...[
                  _SectionHeader(title: '账号安全'),
                  _ListCard(
                    children: [
                      _ListTile(
                        icon: Icons.workspace_premium_outlined,
                        iconColor: MobileTheme.accent,
                        title: '申请成为一级用户',
                        subtitle: _levelUpgradeSubtitle(
                          _profile?.levelUpgradeRequest,
                        ),
                        onTap:
                            _saving ||
                                _profile?.levelUpgradeRequest?.status ==
                                    'pending'
                            ? null
                            : _promptLevelUpgradeRequest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

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
                    Divider(height: 0.5, indent: 56, color: colors.divider),
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
                      onTap: () =>
                          context.push('/profile/settings/notifications'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.vibration_outlined,
                      iconColor: colors.textSecondary,
                      title: '声音与振动',
                      onTap: () => _showComingSoonDialog('声音与振动'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 外观区
                _SectionHeader(title: '外观'),
                _ListCard(
                  children: [
                    _ListTile(
                      icon: Icons.brightness_6_outlined,
                      iconColor: colors.textSecondary,
                      title: '主题',
                      subtitle: _themeModeLabel(
                        ref.watch(appSettingsProvider).themeMode,
                      ),
                      onTap: _showThemeDialog,
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.language_outlined,
                      iconColor: colors.textSecondary,
                      title: '语言',
                      subtitle: _localeLabel(
                        ref.watch(appSettingsProvider).locale ??
                            const Locale('zh', 'CN'),
                      ),
                      onTap: _showLanguageDialog,
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
                      iconColor: colors.textSecondary,
                      title: '用户协议',
                      onTap: () => context.push('/legal/terms'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: colors.textSecondary,
                      title: '隐私政策',
                      onTap: () => context.push('/legal/privacy'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.gavel_outlined,
                      iconColor: colors.textSecondary,
                      title: '社区规范',
                      onTap: () => context.push('/legal/guidelines'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.flag_outlined,
                      iconColor: colors.textSecondary,
                      title: '举报说明',
                      onTap: () => context.push('/legal/report'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    _ListTile(
                      icon: Icons.help_outline,
                      iconColor: colors.textSecondary,
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
                    _ListTile(
                      icon: Icons.download_outlined,
                      iconColor: MobileTheme.primary,
                      title: '下载 Android 客户端',
                      subtitle: '获取当前最新安装包',
                      onTap: () => context.push('/download'),
                    ),
                    Divider(height: 0.5, indent: 56, color: colors.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 22,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '版本号',
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                _SectionHeader(title: '账号安全'),
                _ListCard(
                  children: [
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

                _SectionHeader(title: '致谢'),
                _ListCard(
                  children: [
                    _ListTile(
                      icon: Icons.favorite_outline,
                      iconColor: MobileTheme.primary,
                      title: '致谢页',
                      subtitle: '感谢每一位参与建设与反馈的同学',
                      onTap: () => context.push('/profile/acknowledgements'),
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
                        color: colors.surface,
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

                const SizedBox(height: 16),
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
        content: const Text('账号注销后将永久删除所有数据，且无法恢复。\n\n确认要注销账号吗？'),
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('外观'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeOption(
                title: '跟随系统',
                value: ThemeMode.system,
                current: ref.read(appSettingsProvider).themeMode,
                onTap: () => _setBrightness(ThemeMode.system, ctx),
              ),
              _ThemeOption(
                title: '浅色',
                value: ThemeMode.light,
                current: ref.read(appSettingsProvider).themeMode,
                onTap: () => _setBrightness(ThemeMode.light, ctx),
              ),
              _ThemeOption(
                title: '深色',
                value: ThemeMode.dark,
                current: ref.read(appSettingsProvider).themeMode,
                onTap: () => _setBrightness(ThemeMode.dark, ctx),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setBrightness(
    ThemeMode mode,
    BuildContext dialogContext,
  ) async {
    await ref.read(appSettingsProvider.notifier).setBrightness(mode);
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_themeModeLabel(mode)}');
  }

  String _themeModeLabel(ThemeMode mode) {
    if (mode == ThemeMode.system) return '跟随系统';
    if (mode == ThemeMode.light) return '浅色';
    if (mode == ThemeMode.dark) return '深色';
    return '未知';
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(appSettingsProvider).locale;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('语言'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LocaleOption(
                title: '简体中文',
                locale: const Locale('zh', 'CN'),
                current: currentLocale,
                onTap: () => _setLocale(const Locale('zh', 'CN'), ctx),
              ),
              _LocaleOption(
                title: '繁體中文',
                locale: const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                ),
                current: currentLocale,
                onTap: () => _setLocale(
                  const Locale.fromSubtags(
                    languageCode: 'zh',
                    scriptCode: 'Hant',
                  ),
                  ctx,
                ),
              ),
              _LocaleOption(
                title: 'English',
                locale: const Locale('en', 'US'),
                current: currentLocale,
                onTap: () => _setLocale(const Locale('en', 'US'), ctx),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setLocale(Locale loc, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setLocale(loc);
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_localeLabel(loc)}');
  }

  String _localeLabel(Locale loc) {
    final code = loc.scriptCode != null && loc.scriptCode!.isNotEmpty
        ? '${loc.languageCode}_${loc.scriptCode}'
        : '${loc.languageCode}_${loc.countryCode ?? ''}';
    if (code == 'zh_CN') return '简体中文';
    if (code == 'zh_Hant') return '繁體中文';
    if (code == 'zh_TW') return '繁體中文';
    if (code == 'en_US') return 'English';
    if (code == 'en_') return 'English';
    return '${loc.languageCode}_${loc.countryCode ?? ''}';
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
              const Text('请输入统一认证密码以确认注销申请：', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: '统一认证密码',
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
                        final studentId =
                            AuthStore.instance.currentUser?.studentId ?? '';
                        await ref
                            .read(authRepositoryProvider)
                            .login(
                              identifier: studentId,
                              password: passwordController.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _submitCancellationRequest();
                      } catch (_) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('统一认证密码错误，请重新输入')),
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

class _ThemeOption extends StatelessWidget {
  final String title;
  final ThemeMode value;
  final ThemeMode current;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check, color: MobileTheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _LocaleOption extends StatelessWidget {
  final String title;
  final Locale locale;
  final Locale? current;
  final VoidCallback onTap;

  const _LocaleOption({
    required this.title,
    required this.locale,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected =
        locale.languageCode == current?.languageCode &&
        locale.countryCode == current?.countryCode;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check, color: MobileTheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

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
  final List<Widget> children;

  const _ListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
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
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;

  const _ListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

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
                      color: titleColor ?? colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            activeThumbColor: MobileTheme.primary,
          ),
        ],
      ),
    );
  }
}
