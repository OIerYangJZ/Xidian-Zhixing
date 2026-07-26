import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/core/theme/shared_colors.dart';
import 'package:xdu_treehole_web/core/widgets/language_toggle.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthLoginResult result = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);
      if (!mounted) {
        return;
      }

      if (result.verified && (result.token ?? '').isNotEmpty) {
        try {
          final profile = await ref.read(userRepositoryProvider).fetchProfile();
          AuthStore.instance.setCurrentUser(profile);
        } catch (error) {
          if (!mounted) return;
          _showError(
            l10n.loginFailed(error.toString().replaceAll('Exception: ', '')),
          );
          return;
        }
        if (!mounted) {
          return;
        }
        ref.invalidate(feedControllerProvider);
        ref.invalidate(notificationsControllerProvider);
        ref.invalidate(messagesControllerProvider);
        context.go('/');
        return;
      }

      final String email = (result.email ?? '').trim();
      if (email.isEmpty) {
        _showError(l10n.loginResultError);
        return;
      }
      context.go('/auth/verify?email=${Uri.encodeComponent(email)}');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(l10n.loginFailed('$error'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MobileColors colors = MobileColors.of(context);
    final EditorialColors editorial = EditorialColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final Locale locale = settings.locale ?? const Locale('zh', 'CN');
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    color: colors.primary,
                    child: Text(
                      '知',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: colors.surface),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  LanguageToggle(
                    locale: locale,
                    compact: true,
                    onChanged: ref.read(appSettingsProvider).setLocale,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
                color: colors.textPrimary,
                child: Text(
                  l10n.tagline,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: colors.surface,
                    fontSize: locale.languageCode == 'en' ? 38 : 42,
                    height: 1.08,
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 10,
                      child: ColoredBox(color: editorial.coral),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    height: 10,
                    child: ColoredBox(color: editorial.apricot),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                l10n.welcomeBack,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.loginDescription,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _identifierController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: InputDecoration(
                  labelText: l10n.studentIdentifier,
                  hintText: l10n.studentIdentifierHint,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: l10n.password,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? l10n.showPassword
                        : l10n.hidePassword,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              FilledButton(
                onPressed: _isLoading ? null : _login,
                child: Text(_isLoading ? l10n.loggingIn : l10n.loginButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go('/auth/register'),
                child: Text(l10n.registerAccount),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => context.go('/auth/reset-password'),
                child: Text(l10n.forgotPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
