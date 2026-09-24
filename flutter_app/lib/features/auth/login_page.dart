import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/share_links.dart';
import '../../core/navigation/url_query_state.dart';
import '../../core/network/api_exception.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/language_toggle.dart';
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
  bool _isBusy = false;
  String? _errorText;

  /// Consent to the terms and privacy policy, required before signing in.
  bool _agreed = false;
  bool _agreementHint = false;

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
    final Locale locale = Localizations.localeOf(context);
    return Theme(
      data: AppTheme.lightThemeFor(locale, themeKey: 'mozhuxinye'),
      child: Builder(
        builder: (BuildContext context) {
          final EditorialColors colors = EditorialColors.of(context);
          return Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool desktop =
                      constraints.maxWidth >= AppBreakpoints.medium;
                  if (desktop) {
                    return Row(
                      children: <Widget>[
                        Expanded(
                          flex: 11,
                          child: _LoginManifesto(
                            locale: Localizations.localeOf(context),
                          ),
                        ),
                        Expanded(
                          flex: 9,
                          child: ColoredBox(
                            color: colors.page,
                            child: _LoginForm(
                              isBusy: _isBusy,
                              errorText: _errorText,
                              onLogin: _login,
                              onAdminLogin: _openAdminLogin,
                              onTerms: _openTerms,
                              agreed: _agreed,
                              agreementHint: _agreementHint,
                              onAgreedChanged: _setAgreed,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ColoredBox(
                    color: colors.page,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      child: Column(
                        children: <Widget>[
                          const _CompactBrandHeader(),
                          const SizedBox(height: AppSpacing.lg),
                          _LoginForm(
                            showLanguage: false,
                            isBusy: _isBusy,
                            errorText: _errorText,
                            onLogin: _login,
                            onAdminLogin: _openAdminLogin,
                            onTerms: _openTerms,
                            agreed: _agreed,
                            agreementHint: _agreementHint,
                            onAgreedChanged: _setAgreed,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
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

  void _setAgreed(bool value) {
    setState(() {
      _agreed = value;
      _agreementHint = false;
    });
  }

  Future<void> _login() async {
    if (!_agreed) {
      setState(() => _agreementHint = true);
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      // Opened from a shared link: unified auth returns to that link, and the
      // shell opens it once signed in.
      final ShareLink? link = currentShareLink();
      final XidianAuthSessionResult session = await AppRepositories.auth
          .createXidianAuthSession(
            platform: 'web',
            nextPath: link?.path ?? '/',
          );
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

class _LoginManifesto extends StatelessWidget {
  const _LoginManifesto({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors colors = EditorialColors.of(context);
    return ColoredBox(
      color: colors.darkPanel,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 40, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Wordmark(onDark: true),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Text(
                    l10n.tagline,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: colors.onDarkPanel,
                      fontSize: locale.languageCode == 'en' ? 66 : 74,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    l10n.taglineSupporting,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onDarkPanel.withValues(alpha: 0.76),
                      height: 1.7,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ManifestoNote(
                        title: l10n.readFirst,
                        description: l10n.readFirstDescription,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _ManifestoNote(
                        title: l10n.crossScreen,
                        description: l10n.crossScreenDescription,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManifestoNote extends StatelessWidget {
  const _ManifestoNote({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.onDarkPanel.withValues(alpha: 0.32)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.onDarkPanel),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onDarkPanel.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    this.showLanguage = true,
    required this.isBusy,
    required this.errorText,
    required this.onLogin,
    required this.onAdminLogin,
    required this.onTerms,
    required this.agreed,
    required this.agreementHint,
    required this.onAgreedChanged,
  });

  final bool showLanguage;
  final bool isBusy;
  final String? errorText;
  final VoidCallback onLogin;
  final VoidCallback onAdminLogin;
  final VoidCallback onTerms;
  final bool agreed;

  /// Shown after a sign-in attempt without consent.
  final bool agreementHint;
  final ValueChanged<bool> onAgreedChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors colors = EditorialColors.of(context);
    final Locale locale = Localizations.localeOf(context);
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
              if (showLanguage) ...<Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LanguageToggle(
                        locale: locale,
                        onChanged: AppLocaleStore.instance.setLocale,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 72),
              ] else
                const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.welcomeBack,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.loginDescription,
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
              _AgreementRow(
                agreed: agreed,
                showHint: agreementHint,
                onChanged: onAgreedChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
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
                    Text(isBusy ? l10n.loggingIn : l10n.loginButton),
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

/// 我已阅读并同意《用户协议》和《隐私政策》. The links open the documents
/// without toggling the checkbox.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.agreed,
    required this.showHint,
    required this.onChanged,
  });

  final bool agreed;
  final bool showHint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color danger = theme.colorScheme.error;
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    Widget link(String zh, String en, Widget page) => InkWell(
      onTap: () => open(page),
      child: Text(
        uiText(context, zh: zh, en: en),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHint)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              uiText(
                context,
                zh: '请先阅读并同意用户协议和隐私政策',
                en: 'Please read and accept the Terms and Privacy Policy first',
              ),
              key: const Key('login-agreement-hint'),
              style: TextStyle(color: danger, fontSize: 13),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Checkbox(
              key: const Key('login-agreement'),
              value: agreed,
              onChanged: (bool? value) => onChanged(value ?? false),
              side: BorderSide(
                color: showHint ? danger : theme.colorScheme.outline,
                width: 1.5,
              ),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => onChanged(!agreed),
                    child: Text(
                      uiText(context, zh: '我已阅读并同意', en: 'I have read and accept the '),
                    ),
                  ),
                  link('《用户协议》', 'Terms', const TermsOfServicePage()),
                  Text(uiText(context, zh: '和', en: ' and ')),
                  link('《隐私政策》', 'Privacy Policy', const PrivacyPolicyPage()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final EditorialColors colors = EditorialColors.of(context);
    final Locale locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _Wordmark(),
            const Spacer(),
            LanguageToggle(
              locale: locale,
              onChanged: AppLocaleStore.instance.setLocale,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: colors.darkPanel,
          child: Text(
            l10n.tagline,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colors.onDarkPanel,
              fontSize: locale.languageCode == 'en' ? 38 : 42,
            ),
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          color: colors.primary,
          child: Text(
            '知',
            style: AppTypography.accentStyle(
              const Locale('zh', 'CN'),
              fontSize: 17,
              color: colors.page,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          AppLocalizations.of(context)!.appTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: onDark ? colors.onDarkPanel : colors.ink,
          ),
        ),
      ],
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
      body: ListView(
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
    );
  }
}
