import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../admin/admin_login_page.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import '../../widgets/home_shell.dart';
import 'verify_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isBusy = false;
  String? _errorText;

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFEAF3FB), Color(0xFFF6F8FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '西电树洞',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    const Text('仅限西电学生，前台匿名，后台可追责。'),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _studentIdController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: '学号',
                        hintText: '例如：2023123456',
                        prefixIcon: Icon(Icons.perm_identity_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _login,
                      icon: _isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_isBusy ? '登录中...' : '登录'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('去注册（新账号）'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ResetPasswordPage(),
                                ),
                              );
                            },
                      child: const Text('忘记密码'),
                    ),
                    TextButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AdminLoginPage(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('管理员后台登录'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _LoginTermsRoute(),
                          ),
                        );
                      },
                      child: const Text('用户协议 · 隐私政策 · 社区规范',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final String studentId = _studentIdController.text.trim();
    final String password = _passwordController.text.trim();

    if (studentId.length < 6) {
      setState(() {
        _errorText = '请输入有效学号。';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _errorText = '请输入密码。';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final AuthLoginResult result = await AppRepositories.auth.login(
        identifier: studentId,
        password: password,
      );

      if (!mounted) {
        return;
      }

      if (result.verified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyPage(
            campusEmail: _resolveCampusEmail(studentId, result),
            password: password,
          ),
        ),
      );
    } on ApiException catch (error) {
      // 部分后端会在未认证时直接返回错误，仍允许继续走验证码页。
      final String msg = error.message.toLowerCase();
      if (msg.contains('verify') || msg.contains('验证码') || msg.contains('认证')) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VerifyPage(
              campusEmail: _resolveCampusEmail(studentId, null),
              password: password,
            ),
          ),
        );
      } else {
        _showError(error.message);
      }
    } catch (error) {
      _showError('登录失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _resolveCampusEmail(String studentId, AuthLoginResult? result) {
    final String? email = result?.email?.trim();
    if (email != null &&
        email.isNotEmpty &&
        (email.endsWith('@stu.xidian.edu.cn') || email.endsWith('@xidian.edu.cn'))) {
      return email;
    }
    return '${studentId.trim()}@stu.xidian.edu.cn';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorText = message;
    });
  }
}

class _LoginTermsRoute extends StatelessWidget {
  const _LoginTermsRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('合规说明'),
        backgroundColor: const Color(0xFF0E7490),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildLinkCard(
            context,
            icon: Icons.description_outlined,
            title: '用户协议',
            subtitle: '了解平台服务条款与用户行为规范',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TermsOfServicePage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildLinkCard(
            context,
            icon: Icons.shield_outlined,
            title: '隐私政策',
            subtitle: '了解我们如何收集、使用和保护您的信息',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildLinkCard(
            context,
            icon: Icons.groups_outlined,
            title: '社区规范',
            subtitle: '了解社区规则与内容管理政策',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CommunityGuidelinesPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0E7490).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0E7490)),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
