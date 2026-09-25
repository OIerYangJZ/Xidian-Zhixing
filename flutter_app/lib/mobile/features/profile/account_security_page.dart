import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';

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

    final bool confirmed = await zxConfirm(
      context,
      title: '申请成为一级用户',
      message: '一级用户可以发帖后立即置顶。提交后由管理员审核。',
      confirmLabel: '提交申请',
      cancelLabel: '取消',
    );
    if (!confirmed) return;

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
    zxShowToast(context, message);
  }

  String _maskedStudentId(String id) {
    final String v = id.trim();
    if (v.length <= 6) return v;
    return '${v.substring(0, 2)}****${v.substring(v.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final UserProfile? p = _profile;
    final Locale locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: ZxPaper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : p == null
            ? ZxStatePanel(
                error: true,
                icon: Icons.error_outline_rounded,
                title: '账号信息加载失败',
                message: _error,
                actionLabel: '重试',
                onAction: _loadProfile,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  ZxCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.successSoft,
                            borderRadius: ZxRadius.buttonAll,
                          ),
                          child: Icon(
                            Icons.badge_outlined,
                            color: t.success,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '西电统一身份认证',
                                style: ZxType.label.copyWith(color: t.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.studentId.trim().isEmpty
                                    ? '已登录'
                                    : '已登录 · ${_maskedStudentId(p.studentId)}',
                                style: ZxType.caption.copyWith(color: t.text3),
                              ),
                            ],
                          ),
                        ),
                        if (p.verified) const ZxBadge.verified('已认证'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ZxListSection(
                    title: '用户等级',
                    children: [
                      ZxListItem(
                        key: const Key('mobile-account-level'),
                        icon: Icons.workspace_premium_outlined,
                        title: p.isLevelOneUser ? '一级用户' : '申请成为一级用户',
                        subtitle: p.isLevelOneUser
                            ? '可以发帖后立即置顶'
                            : _levelUpgradeSubtitle(p.levelUpgradeRequest),
                        trailing: ZxBadge.level(p.userLevelLabelFor(locale)),
                        onTap:
                            p.isLevelOneUser ||
                                _saving ||
                                p.levelUpgradeRequest?.status == 'pending'
                            ? null
                            : _promptLevelUpgradeRequest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ZxListSection(
                    title: '账号',
                    children: [
                      ZxListItem(
                        key: const Key('mobile-account-cancel'),
                        icon: Icons.no_accounts_outlined,
                        title: '注销账号',
                        subtitle: '停用账号并进入可申诉恢复状态',
                        danger: true,
                        onTap: _showCancelAccountHint,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showCancelAccountHint() async {
    final bool go = await zxConfirm(
      context,
      title: '注销账号',
      message: '审核通过后账号将停用并退出所有会话；必要的账号与内容记录会按隐私政策保留，之后可提交申诉恢复。\n\n确认要申请注销吗？',
      confirmLabel: '继续注销',
      cancelLabel: '取消',
      danger: true,
    );
    if (go && mounted) _showCancelAccountReauthentication();
  }

  void _showCancelAccountReauthentication() {
    bool submitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('验证身份'),
          content: const Text('为确认由本人操作，将前往西电官方统一身份认证页面重新验证。西电知行不会接触你的统一认证密码。'),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ZxTokens.of(ctx).danger,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        final repository = ref.read(authRepositoryProvider);
                        final XidianAuthSessionResult created = await repository
                            .createXidianAuthSession(platform: 'mobile');
                        final bool launched = await launchUrl(
                          Uri.parse(created.authorizeUrl!),
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched) {
                          throw StateError('无法打开西电官方统一身份认证页面');
                        }
                        XidianAuthSessionResult? authenticated;
                        for (int poll = 0; poll < 300; poll += 1) {
                          await Future<void>.delayed(
                            const Duration(seconds: 2),
                          );
                          final XidianAuthSessionResult session =
                              await repository.fetchXidianAuthSession(
                                created.attemptId,
                              );
                          if (session.isFailed) {
                            throw StateError(session.message ?? '统一认证登录失败');
                          }
                          if (session.isAuthenticated) {
                            authenticated = session;
                            break;
                          }
                        }
                        if (authenticated == null) {
                          throw StateError('统一认证登录已超时，请重新操作');
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _submitCancellationRequest();
                      } catch (error) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.toString().replaceFirst(
                                  RegExp(r'^(Exception|Bad state): '),
                                  '',
                                ),
                              ),
                            ),
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
            '注销申请已提交给管理员审核。审核通过后账号将停用并退出所有会话；必要记录按隐私政策保留，之后可提交申诉恢复。\n\n请在应用内查看审核结果。',
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
    } catch (_) {
      _showToast('申请提交失败，请稍后重试');
    }
  }

  Future<void> _logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (error) {
      _showToast('退出失败：$error');
      return;
    }
    if (!mounted) return;
    context.go('/auth/login');
  }
}
