import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLoading = false;
  String? _errorMessage;
  int _loginGeneration = 0;

  @override
  void dispose() {
    _loginGeneration += 1;
    super.dispose();
  }

  Future<void> _login() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int generation = ++_loginGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
        if (!mounted || generation != _loginGeneration) {
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        final XidianAuthSessionResult session = await repository
            .fetchXidianAuthSession(created.attemptId);
        if (session.isFailed) {
          throw StateError(session.message ?? '统一认证登录失败');
        }
        if (session.isAuthenticated) {
          authenticated = session;
          break;
        }
      }
      if (authenticated == null) {
        throw StateError('统一认证登录已超时，请重新发起登录');
      }
      await _finishLogin();
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(l10n.loginFailed('$error'));
    } finally {
      if (mounted && generation == _loginGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _finishLogin() async {
    final profile = await ref.read(userRepositoryProvider).fetchProfile();
    AuthStore.instance.setCurrentUser(profile);
    if (!mounted) {
      return;
    }
    ref.invalidate(feedControllerProvider);
    ref.invalidate(notificationsControllerProvider);
    ref.invalidate(messagesControllerProvider);
    context.go('/');
  }

  void _cancelLogin() {
    _loginGeneration += 1;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
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
              const SizedBox.shrink(),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (_isLoading) ...<Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(_isLoading ? l10n.loggingIn : l10n.loginButton),
                    if (!_isLoading) ...<Widget>[
                      const SizedBox(width: 8),
                      const Icon(Icons.open_in_new, size: 18),
                    ],
                  ],
                ),
              ),
              if (_isLoading)
                TextButton(onPressed: _cancelLogin, child: const Text('取消等待')),
            ],
          ),
        ),
      ),
    );
  }
}
