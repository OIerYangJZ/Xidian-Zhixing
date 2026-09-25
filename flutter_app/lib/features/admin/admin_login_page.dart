import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../design_system/design_system.dart';
import '../../repositories/app_repositories.dart';
import 'admin_portal_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, this.onSignedIn});

  /// Where to go once signed in; the web opens its admin portal. The Android
  /// app passes its own route here.
  final VoidCallback? onSignedIn;

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
    return Theme(
      // The admin side's palette, as in AdminPortalPage.
      data: AppTheme.designSystemFor(
        themeKey: 'zhuqing',
        brightness: Theme.of(context).brightness,
      ),
      child: Builder(
        builder: (BuildContext context) {
          final ZxTokens t = ZxTokens.of(context);
          return Scaffold(
            appBar: AppBar(title: const Text('管理员后台')),
            body: ZxPaper(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ZxCard(
                      padding: const EdgeInsets.all(28),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const ZxAvatar.anonymous(name: '知', size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '管理工作台登录',
                                        style: ZxType.headline.copyWith(
                                          color: t.text,
                                        ),
                                      ),
                                      Text(
                                        '管理员账号与普通用户账号完全独立。',
                                        style: ZxType.caption.copyWith(
                                          color: t.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const ZxInlineMessage(
                              message: '受限入口：仅授权项目成员可进入；请勿在共享设备保存管理员凭据。',
                              tone: ZxMessageTone.warning,
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              key: const Key('admin-username'),
                              controller: _usernameController,
                              enabled: !_submitting,
                              autofillHints: const <String>[
                                AutofillHints.username,
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '管理员账号',
                                prefixIcon: Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('admin-password'),
                              controller: _passwordController,
                              enabled: !_submitting,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              obscureText: true,
                              onSubmitted: (_) => _login(),
                              decoration: const InputDecoration(
                                labelText: '管理员密码',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: 12),
                              ZxInlineMessage(
                                key: const Key('admin-login-error'),
                                message: _error!,
                                tone: ZxMessageTone.danger,
                              ),
                            ],
                            const SizedBox(height: 20),
                            ZxButton(
                              key: const Key('admin-login-submit'),
                              label: _submitting ? '正在验证' : '登录管理工作台',
                              icon: Icons.login_rounded,
                              loading: _submitting,
                              expand: true,
                              onPressed: _submitting ? null : _login,
                            ),
                          ],
                        ),
                      ),
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
      final VoidCallback? onSignedIn = widget.onSignedIn;
      if (onSignedIn != null) {
        onSignedIn();
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
