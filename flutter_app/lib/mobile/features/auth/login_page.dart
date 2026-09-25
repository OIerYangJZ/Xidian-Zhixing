import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/l10n/ui_text.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import '../../core/navigation/login_return.dart';
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

  /// Consent to the terms and privacy policy, required before signing in.
  bool _agreed = false;
  bool _agreementHint = false;

  /// Bumped on each sign-in attempt without consent, to shake the checkbox.
  int _nudges = 0;

  @override
  void dispose() {
    _loginGeneration += 1;
    super.dispose();
  }

  Future<void> _login() async {
    if (!_agreed) {
      setState(() {
        _agreementHint = true;
        _nudges++;
      });
      return;
    }
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
    context.go(loginReturnLocation(GoRouterState.of(context).uri));
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
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String from = loginReturnLocation(GoRouterState.of(context).uri);
    final String? sharedKind = from.startsWith('/post/')
        ? uiText(
            context,
            zh: '登录后将打开分享的帖子',
            en: 'The shared post opens after you sign in',
          )
        : from.startsWith('/user/')
        ? uiText(
            context,
            zh: '登录后将打开分享的主页',
            en: 'The shared profile opens after you sign in',
          )
        : null;

    // Handoff L2: the brand on the hero wash over a bottom sign-in panel.
    return Scaffold(
      body: ZxHeroWash(
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -70,
              top: 120,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Text(
                    '知',
                    style: TextStyle(
                      fontFamily: ZxFonts.display,
                      fontFamilyFallback: ZxFonts.displayFallback,
                      fontSize: 340,
                      height: 1,
                      color: t.primary.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerRight,
                          child: _LanguageSwitch(
                            onChanged: ref.read(appSettingsProvider).setLocale,
                          ),
                        ),
                        if (sharedKind != null) ...<Widget>[
                          const SizedBox(height: 12),
                          _ShareCard(text: sharedKind),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const ZxAvatar.anonymous(name: '知', size: 76),
                            const SizedBox(height: 16),
                            Text(
                              uiText(context, zh: '西电知行', en: 'Xidian Zhixing'),
                              style: ZxType.display.copyWith(color: t.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'XIDIAN ZHIXING',
                              style: ZxType.micro.copyWith(
                                color: t.text3,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.tagline,
                              textAlign: TextAlign.center,
                              style: ZxType.body.copyWith(color: t.text2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ZxRadius.sheet),
                      ),
                      border: Border(top: BorderSide(color: t.line)),
                      boxShadow: t.shadow2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_errorMessage != null) ...<Widget>[
                          ZxInlineMessage(
                            key: const Key('mobile-login-error'),
                            message: _errorMessage!,
                            tone: ZxMessageTone.danger,
                          ),
                          const SizedBox(height: 12),
                        ],
                        ZxButton(
                          key: const Key('mobile-login-submit'),
                          label: _isLoading
                              ? l10n.loggingIn
                              : uiText(
                                  context,
                                  zh: '西电统一身份认证登录',
                                  en: 'Sign in with Xidian',
                                ),
                          icon: Icons.badge_outlined,
                          loading: _isLoading,
                          expand: true,
                          onPressed: _isLoading ? null : _login,
                        ),
                        const SizedBox(height: 10),
                        if (_isLoading)
                          Center(
                            child: TextButton(
                              onPressed: _cancelLogin,
                              child: Text(
                                uiText(context, zh: '取消等待', en: 'Stop waiting'),
                              ),
                            ),
                          )
                        else
                          Text(
                            uiText(
                              context,
                              zh: '将跳转到学校统一身份认证页面，用学号和密码登录',
                              en: 'You will continue to Xidian’s sign-in page and use your student ID and password.',
                            ),
                            textAlign: TextAlign.center,
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                        const SizedBox(height: 12),
                        _buildAgreement(t),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 我已阅读并同意《用户协议》和《隐私政策》. The links open the documents
  /// without toggling the checkbox. Signing in without consent raises a
  /// bubble above it, outlines it in danger and shakes it once.
  Widget _buildAgreement(ZxTokens t) {
    void toggle(bool value) => setState(() {
      _agreed = value;
      _agreementHint = false;
    });
    Widget link(String zh, String en, String route) => InkWell(
      onTap: () => context.push(route),
      child: Text(
        uiText(context, zh: zh, en: en),
        style: ZxType.caption.copyWith(
          fontSize: 13,
          color: t.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final TextStyle plain = ZxType.caption.copyWith(
      fontSize: 13,
      color: t.text2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_agreementHint)
          Container(
            key: const Key('mobile-login-agreement-hint'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.raised,
              borderRadius: ZxRadius.badgeAll,
              border: Border.all(color: t.line),
              boxShadow: t.shadow1,
            ),
            child: Text(
              uiText(
                context,
                zh: '请先阅读并同意用户协议和隐私政策',
                en: 'Please read and accept the Terms and Privacy Policy first',
              ),
              style: ZxType.caption.copyWith(
                color: t.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TweenAnimationBuilder<double>(
          key: ValueKey<int>(_nudges),
          tween: Tween<double>(begin: _nudges == 0 ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 420),
          builder: (BuildContext context, double v, Widget? child) =>
              Transform.translate(
                offset: Offset(math.sin(v * math.pi * 4) * 5 * (1 - v), 0),
                child: child,
              ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  key: const Key('mobile-login-agreement'),
                  value: _agreed,
                  onChanged: (bool? value) => toggle(value ?? false),
                  side: BorderSide(
                    color: _agreementHint ? t.danger : t.lineStrong,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    GestureDetector(
                      onTap: () => toggle(!_agreed),
                      child: Text(
                        uiText(
                          context,
                          zh: '我已阅读并同意',
                          en: 'I have read and accept the ',
                        ),
                        style: plain,
                      ),
                    ),
                    link('《用户协议》', 'Terms', '/legal/terms'),
                    Text(
                      uiText(context, zh: '和', en: ' and '),
                      style: plain,
                    ),
                    link('《隐私政策》', 'Privacy Policy', '/legal/privacy'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 中文 / EN, before signing in.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.onChanged});

  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    return SegmentedButton<bool>(
      key: const Key('mobile-login-language'),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('中文')),
        ButtonSegment<bool>(value: true, label: Text('EN')),
      ],
      selected: <bool>{english},
      onSelectionChanged: (Set<bool> value) => onChanged(
        value.first ? const Locale('en') : const Locale('zh', 'CN'),
      ),
    );
  }
}

/// 登录后将打开分享的帖子 / 主页, when the guard sent a shared link here.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      key: const Key('mobile-login-share-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: ZxRadius.cardAll,
        border: Border.all(color: t.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: ZxRadius.smallButtonAll,
            ),
            child: Icon(Icons.link_rounded, size: 18, color: t.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: ZxType.label.copyWith(color: t.text)),
          ),
        ],
      ),
    );
  }
}
