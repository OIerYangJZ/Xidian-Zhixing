import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/state/app_locale_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/language_toggle.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
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
    final Locale locale = Localizations.localeOf(context);
    return Theme(
      data: AppTheme.lightThemeFor(locale),
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
                          child: _LoginManifesto(locale: locale),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: colors.line,
                        ),
                        Expanded(
                          flex: 9,
                          child: ColoredBox(
                            color: colors.page,
                            child: _LoginForm(
                              isBusy: _isBusy,
                              obscurePassword: _obscurePassword,
                              errorText: _errorText,
                              identifierController: _identifierController,
                              passwordController: _passwordController,
                              onLogin: _login,
                              onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              onRegister: _openRegister,
                              onResetPassword: _openResetPassword,
                              onTerms: _openTerms,
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
                            obscurePassword: _obscurePassword,
                            errorText: _errorText,
                            identifierController: _identifierController,
                            passwordController: _passwordController,
                            onLogin: _login,
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onRegister: _openRegister,
                            onResetPassword: _openResetPassword,
                            onTerms: _openTerms,
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

  void _openTerms() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermsOfServicePage()));
  }

  Future<void> _login() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text.trim();
    if (identifier.isEmpty) {
      _showError(l10n.identifierRequired);
      return;
    }
    if (password.isEmpty) {
      _showError(l10n.passwordRequired);
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
        _showError(l10n.loginResultError);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VerifyPage(campusEmail: email)),
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
          Positioned(
            right: 0,
            top: 0,
            width: 168,
            height: 168,
            child: ColoredBox(color: colors.coral),
          ),
          Positioned(
            right: 168,
            top: 0,
            width: 72,
            height: 168,
            child: ColoredBox(color: colors.apricot),
          ),
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
                    style: AppTypography.brandStyle(
                      locale,
                      color: colors.onDarkPanel,
                      fontSize: locale.languageCode == 'en' ? 66 : 74,
                      height: 1.05,
                    ),
                  ),
                ),
                const Spacer(),
              ],
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
    required this.obscurePassword,
    required this.errorText,
    required this.identifierController,
    required this.passwordController,
    required this.onLogin,
    required this.onTogglePassword,
    required this.onRegister,
    required this.onResetPassword,
    required this.onTerms,
  });

  final bool showLanguage;
  final bool isBusy;
  final bool obscurePassword;
  final String? errorText;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;
  final VoidCallback onResetPassword;
  final VoidCallback onTerms;

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
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showLanguage) ...<Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: LanguageToggle(
                      locale: locale,
                      onChanged: AppLocaleStore.instance.setLocale,
                    ),
                  ),
                  const SizedBox(height: 72),
                ] else
                  const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeBack,
                  style: AppTypography.brandStyle(
                    locale,
                    color: colors.ink,
                    fontSize: locale.languageCode == 'en' ? 36 : 38,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  key: const Key('login-identifier'),
                  controller: identifierController,
                  enabled: !isBusy,
                  autofillHints: const <String>[
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: AppInput.decoration(
                    hintText: l10n.studentIdentifier,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('login-password'),
                  controller: passwordController,
                  enabled: !isBusy,
                  autofillHints: const <String>[AutofillHints.password],
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onLogin(),
                  decoration: AppInput.decoration(
                    hintText: l10n.password,
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? l10n.showPassword
                          : l10n.hidePassword,
                      onPressed: isBusy ? null : onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
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
                      Text(isBusy ? l10n.loggingIn : l10n.loginButton),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: isBusy ? null : onRegister,
                  child: Text(l10n.registerAccount),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    TextButton(
                      onPressed: onTerms,
                      child: Text(l10n.agreements),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    TextButton(
                      onPressed: isBusy ? null : onResetPassword,
                      child: Text(l10n.forgotPassword),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
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
    final Locale locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AppBrandLogo(size: 30),
        const SizedBox(width: AppSpacing.sm),
        Text(
          AppLocalizations.of(context)!.appTitle,
          style: AppTypography.wordmarkStyle(
            locale,
            color: onDark ? colors.onDarkPanel : colors.ink,
          ),
        ),
      ],
    );
  }
}
