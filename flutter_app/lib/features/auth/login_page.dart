import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../admin/admin_login_page.dart';
import '../../widgets/home_shell.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import 'verify_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= AppBreakpoints.medium;
          final EdgeInsets padding = AppLayout.pagePadding(context);
          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.authMaxWidth,
                  ),
                  child: desktop
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Expanded(child: _LoginIntroPanel()),
                              const SizedBox(width: AppSpacing.lg),
                              SizedBox(
                                width: 440,
                                child: _buildLoginCard(context),
                              ),
                            ],
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            children: <Widget>[
                              const _LoginCompactHeader(),
                              const SizedBox(height: AppSpacing.md),
                              _buildLoginCard(context),
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

  Widget _buildLoginCard(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(
        AppBreakpoints.isCompact(context) ? AppSpacing.lg : AppSpacing.xl,
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('欢迎回来', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '使用项目组白名单中的学生账号登录。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('login-identifier'),
              controller: _identifierController,
              enabled: !_isBusy,
              autofillHints: const <String>[
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '学号或学生邮箱',
                hintText: '2023123456 或 学生邮箱',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('login-password'),
              controller: _passwordController,
              enabled: !_isBusy,
              autofillHints: const <String>[AutofillHints.password],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                  onPressed: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppInlineMessage(
                key: const Key('login-error'),
                message: _errorText!,
                tone: AppMessageTone.error,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('login-submit'),
              onPressed: _isBusy ? null : _login,
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isBusy ? '正在登录' : '登录'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : _openRegister,
                    child: const Text('注册账号'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextButton(
                    onPressed: _isBusy ? null : _openResetPassword,
                    child: const Text('忘记密码'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppInlineMessage(
              title: '内测访问说明',
              message: '仅白名单 @stu.xidian.edu.cn 账号可使用；学校一站式登录尚未启用。',
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: _isBusy ? null : _openAdminLogin,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('管理员后台登录'),
            ),
            TextButton(
              onPressed: _openTerms,
              child: const Text('用户协议 · 隐私政策 · 社区规范'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
  }

  void _openResetPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()));
  }

  void _openAdminLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminLoginPage()));
  }

  void _openTerms() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _LoginTermsRoute()));
  }

  Future<void> _login() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text.trim();
    if (identifier.isEmpty) {
      _showError('请输入学号或学生邮箱。');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码。');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final AuthLoginResult result = await AppRepositories.auth.login(
        identifier: identifier,
        password: password,
      );
      if (!mounted) {
        return;
      }
      if (result.verified && (result.token ?? '').isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          (Route<dynamic> route) => false,
        );
        return;
      }
      final String email = result.email?.trim() ?? '';
      if (email.isEmpty) {
        _showError('登录结果异常，请稍后重试。');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VerifyPage(campusEmail: email)),
      );
    } on ApiException catch (error) {
      _showError(error.message);
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

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorText = message;
    });
  }
}

class _LoginIntroPanel extends StatelessWidget {
  const _LoginIntroPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[SharedColors.deep, SharedColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.hero),
        boxShadow: AppElevation.soft(SharedColors.deep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Text(
              '项目组内测',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '西电知行',
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '把帖子本身放在阅读中心，让校园里的经验、求助与讨论更清楚地发生。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _IntroPoint(
            icon: Icons.chrome_reader_mode_outlined,
            title: '阅读优先',
            subtitle: '克制的正文宽度与清晰的信息层级',
          ),
          const SizedBox(height: AppSpacing.md),
          const _IntroPoint(
            icon: Icons.devices_outlined,
            title: '跨屏可用',
            subtitle: '适配电脑、平板与手机浏览器',
          ),
          const Spacer(),
          Text(
            '校园社区内测项目 · 非西电官方应用',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginCompactHeader extends StatelessWidget {
  const _LoginCompactHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[SharedColors.deep, SharedColors.bright],
              ),
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('西电知行', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '校园社区内测项目 · 非西电官方应用',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoginTermsRoute extends StatelessWidget {
  const _LoginTermsRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('协议与规范')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TermsOfServicePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('社区规范'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommunityGuidelinesPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
