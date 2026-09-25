import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/url_query_state.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/home_shell.dart';
import '../admin/admin_login_page.dart';
import '../../core/l10n/ui_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const bool _localTestLoginEnabled = bool.fromEnvironment(
    'LOCAL_TEST_LOGIN',
    defaultValue: false,
  );

  bool _isBusy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final String? attemptId = takeQueryParameterFromUrl('xidianAuthAttempt');
    if (attemptId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeWebAuthentication(attemptId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppPageFrame(
          maxWidth: 560,
          padding: EdgeInsets.zero,
          child: _LoginForm(
            isBusy: _isBusy,
            errorText: _errorText,
            onLogin: _login,
            onAdminLogin: _openAdminLogin,
            onTerms: _openTerms,
          ),
        ),
      ),
    );
  }

  void _openAdminLogin() {
    if (!AppConfig.adminConsoleEnabled) {
      return;
    }
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
    if (_localTestLoginEnabled) {
      final bool launched = await launchUrl(
        Uri.base.resolve('/local-test-login.html'),
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        _showError(
          uiTextGlobal(
            zh: '无法打开本地测试登录入口',
            en: 'Could not open the local test login entry',
          ),
        );
      }
      return;
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      final XidianAuthSessionResult session = await AppRepositories.auth
          .createXidianAuthSession(platform: 'web', nextPath: '/');
      final String authorizeUrl = session.authorizeUrl!;
      final bool launched = await launchUrl(
        Uri.parse(authorizeUrl),
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        throw StateError(
          uiTextGlobal(
            zh: '无法打开西电官方统一身份认证页面',
            en: 'Could not open the Xidian single sign-on page',
          ),
        );
      }
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(l10n.loginFailed('$error'));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _completeWebAuthentication(String attemptId) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      final XidianAuthSessionResult session = await AppRepositories.auth
          .fetchXidianAuthSession(attemptId);
      if (session.isFailed) {
        throw StateError(
          session.message ??
              uiTextGlobal(zh: '统一认证登录失败', en: 'Single sign-on failed'),
        );
      }
      if (!session.isAuthenticated) {
        throw StateError(
          uiTextGlobal(
            zh: '统一认证尚未完成，请重新发起登录',
            en: 'Single sign-on is not complete. Please start the login again.',
          ),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        (Route<dynamic> route) => false,
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(l10n.loginFailed('$error'));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _errorText = message);
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.isBusy,
    required this.errorText,
    required this.onLogin,
    required this.onAdminLogin,
    required this.onTerms,
  });

  final bool isBusy;
  final String? errorText;
  final VoidCallback onLogin;
  final VoidCallback onAdminLogin;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors colors = EditorialColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: 38,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.welcomeBack,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _LoginPageState._localTestLoginEnabled
                    ? uiText(
                        context,
                        zh: '本地验收模式：点击后直接使用隔离测试账号登录。',
                        en: 'Local acceptance mode: sign in directly with the isolated test account.',
                      )
                    : l10n.loginDescription,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.mutedInk),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(key: Key('official-auth-notice'), height: 0),
              if (errorText != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                AppInlineMessage(
                  key: const Key('login-error'),
                  message: errorText!,
                  tone: AppMessageTone.error,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: isBusy ? null : onLogin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (isBusy) ...<Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      isBusy
                          ? l10n.loggingIn
                          : _LoginPageState._localTestLoginEnabled
                          ? uiText(
                              context,
                              zh: '一站式登录（本地测试账号）',
                              en: 'Continue with local test account',
                            )
                          : l10n.loginButton,
                    ),
                    if (!isBusy) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.open_in_new, size: 18),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Only the separate admin bundle carries the backoffice; see
              // AppConfig.adminConsoleEnabled.
              if (AppConfig.adminConsoleEnabled)
                TextButton(
                  onPressed: isBusy ? null : onAdminLogin,
                  child: Text(l10n.adminLogin),
                ),
              TextButton(onPressed: onTerms, child: Text(l10n.agreements)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginTermsRoute extends StatelessWidget {
  const _LoginTermsRoute();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.agreements)),
      body: AppPageFrame(
        maxWidth: 720,
        padding: EdgeInsets.zero,
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(uiText(context, zh: '用户协议', en: 'Terms of Service')),
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
              title: Text(uiText(context, zh: '隐私政策', en: 'Privacy Policy')),
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
              title: Text(
                uiText(context, zh: '社区规范', en: 'Community Guidelines'),
              ),
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
      ),
    );
  }
}
