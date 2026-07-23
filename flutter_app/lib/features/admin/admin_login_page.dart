import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../repositories/app_repositories.dart';
import 'admin_portal_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData adminTheme = AppTheme.adminTheme(
      Theme.of(context).brightness,
    );
    return Theme(
      data: adminTheme,
      child: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('管理员后台')),
            body: AppPageFrame(
              maxWidth: 480,
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: AppSurfaceCard(
                  highlighted: true,
                  padding: EdgeInsets.all(
                    AppBreakpoints.isCompact(context)
                        ? AppSpacing.lg
                        : AppSpacing.xl,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '管理工作台登录',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '管理员账号与普通用户账号完全独立。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const AppInlineMessage(
                          title: '受限入口',
                          message: '仅授权项目成员可进入；请勿在共享设备保存管理员凭据。',
                          tone: AppMessageTone.warning,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const Key('admin-username'),
                          controller: _usernameController,
                          enabled: !_submitting,
                          autofillHints: const <String>[AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '管理员账号',
                            prefixIcon: Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          key: const Key('admin-password'),
                          controller: _passwordController,
                          enabled: !_submitting,
                          autofillHints: const <String>[AutofillHints.password],
                          obscureText: true,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            labelText: '管理员密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          AppInlineMessage(
                            key: const Key('admin-login-error'),
                            message: _error!,
                            tone: AppMessageTone.error,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          key: const Key('admin-login-submit'),
                          onPressed: _submitting ? null : _login,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_submitting ? '正在验证' : '登录管理工作台'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _login() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = '请输入管理员账号和密码';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppRepositories.adminAuth.login(
        username: username,
        password: password,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AdminPortalPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '登录失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
