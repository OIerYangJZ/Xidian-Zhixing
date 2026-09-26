import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart' show bannedAccountPage;
import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/navigation/share_links.dart';
import '../../core/navigation/url_query_state.dart';
import '../../core/network/api_exception.dart';
import '../../core/state/app_locale_store.dart';
import '../../design_system/design_system.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/home_shell.dart';
import '../admin/admin_login_page.dart';

/// 登录 (handoff L1–L3): Xidian unified sign-in behind the terms consent.
/// Wide screens pair the tagline with the sign-in card; narrow ones stack
/// the brand over a bottom panel. From a shared link, a card says what
/// opens after signing in.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.debugShareLink});

  /// Stands in for the link in the address bar, for tests and captures.
  @visibleForTesting
  final ShareLink? debugShareLink;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const double _splitMinWidth = 900;

  bool _isBusy = false;
  String? _errorText;

  /// Consent to the terms and privacy policy, required before signing in.
  bool _agreed = false;
  bool _agreementHint = false;

  /// Bumped on each sign-in attempt without consent, to shake the checkbox.
  int _nudges = 0;

  late final ShareLink? _shareLink =
      widget.debugShareLink ?? currentShareLink();

  @override
  void initState() {
    super.initState();
    if (AuthStore.instance.takeSessionExpiredNotice()) {
      _errorText = uiTextGlobal(
        zh: '登录已失效，请重新登录',
        en: 'Your session has ended. Please sign in again.',
      );
    }
    final String? attemptId = takeQueryParameterFromUrl('xidianAuthAttempt');
    if (attemptId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeWebAuthentication(attemptId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget panel = _SignInPanel(
      isBusy: _isBusy,
      errorText: _errorText,
      onLogin: _login,
      onAdminLogin: _openAdminLogin,
      agreed: _agreed,
      agreementHint: _agreementHint,
      nudges: _nudges,
      onAgreedChanged: _setAgreed,
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= _splitMinWidth) {
            return _WideLayout(shareLink: _shareLink, panel: panel);
          }
          return _NarrowLayout(shareLink: _shareLink, panel: panel);
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

  void _setAgreed(bool value) {
    setState(() {
      _agreed = value;
      _agreementHint = false;
    });
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
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      // Opened from a shared link: unified auth returns to that link, and the
      // shell opens it once signed in.
      final ShareLink? link = _shareLink;
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
        MaterialPageRoute<void>(
          builder: (_) =>
              session.banned ? bannedAccountPage() : const HomeShell(),
        ),
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

/// 知 in the display face, large and faint behind the brand.
class _Watermark extends StatelessWidget {
  const _Watermark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Text(
          '知',
          style: TextStyle(
            fontFamily: ZxFonts.display,
            fontFamilyFallback: ZxFonts.displayFallback,
            fontSize: size,
            height: 1,
            color: t.primary.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const ZxAvatar.anonymous(name: '知', size: 40),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              uiText(context, zh: '西电知行', en: 'Xidian Zhixing'),
              style: ZxType.headline.copyWith(
                fontSize: 19,
                height: 1.2,
                color: t.text,
              ),
            ),
            Text(
              'XIDIAN ZHIXING',
              style: ZxType.micro.copyWith(
                color: t.text3,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 中文 / English.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    return SegmentedButton<bool>(
      key: const Key('login-language'),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: false, label: Text('中文')),
        ButtonSegment<bool>(value: true, label: Text('English')),
      ],
      selected: <bool>{english},
      onSelectionChanged: (Set<bool> value) =>
          AppLocaleStore.instance.setLocale(
            value.first ? const Locale('en') : const Locale('zh', 'CN'),
          ),
    );
  }
}

/// 登录后将打开分享的帖子 / 主页. The title is not fetched: signed-out
/// requests cannot read the post.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.link});

  final ShareLink link;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      key: const Key('login-share-card'),
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
            child: Text(
              link.kind == ShareLinkKind.post
                  ? uiText(
                      context,
                      zh: '登录后将打开分享的帖子',
                      en: 'The shared post opens after you sign in',
                    )
                  : uiText(
                      context,
                      zh: '登录后将打开分享的主页',
                      en: 'The shared profile opens after you sign in',
                    ),
              style: ZxType.label.copyWith(color: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.shareLink, required this.panel});

  final ShareLink? shareLink;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 11,
          child: ZxHeroWash(
            child: ClipRect(
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    right: -40,
                    bottom: -90,
                    child: _Watermark(size: 460),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(64, 48, 48, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _Wordmark(),
                        const Spacer(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Text(
                            // Break after 的, as set in the handoff.
                            Localizations.localeOf(context).languageCode == 'zh'
                                ? l10n.tagline.replaceFirst('的', '的\n')
                                : l10n.tagline,
                            style: ZxType.display.copyWith(
                              fontSize: 54,
                              height: 1.3,
                              color: t.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          uiText(
                            context,
                            zh: '西安电子科技大学校园社区',
                            en: 'The Xidian University campus community',
                          ),
                          style: ZxType.body.copyWith(color: t.text2),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 9,
          child: ColoredBox(
            color: t.bg,
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _LanguageSwitch(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (shareLink != null) ...<Widget>[
                                _ShareCard(link: shareLink!),
                                const SizedBox(height: 16),
                              ],
                              ZxCard(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Text(
                                      uiText(
                                        context,
                                        zh: '登录西电知行',
                                        en: 'Sign in to Xidian Zhixing',
                                      ),
                                      style: ZxType.headline.copyWith(
                                        color: t.text,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      uiText(
                                        context,
                                        zh: '使用西电统一身份认证账号登录',
                                        en: 'Sign in with your Xidian unified account',
                                      ),
                                      style: ZxType.body.copyWith(
                                        color: t.text2,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    panel,
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _FooterLinks(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.shareLink, required this.panel});

  final ShareLink? shareLink;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ZxHeroWash(
      child: Stack(
        children: <Widget>[
          const Positioned(right: -70, top: 120, child: _Watermark(size: 340)),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.centerRight,
                        child: _LanguageSwitch(),
                      ),
                      if (shareLink != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _ShareCard(link: shareLink!),
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
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[panel],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sign-in button, its note, errors, the consent row and, where the
/// bundle carries it, the admin entry.
class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    required this.isBusy,
    required this.errorText,
    required this.onLogin,
    required this.onAdminLogin,
    required this.agreed,
    required this.agreementHint,
    required this.nudges,
    required this.onAgreedChanged,
  });

  final bool isBusy;
  final String? errorText;
  final VoidCallback onLogin;
  final VoidCallback onAdminLogin;
  final bool agreed;

  /// Shown after a sign-in attempt without consent.
  final bool agreementHint;
  final int nudges;
  final ValueChanged<bool> onAgreedChanged;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(key: Key('official-auth-notice'), height: 0),
        if (errorText != null) ...<Widget>[
          ZxInlineMessage(
            key: const Key('login-error'),
            message: errorText!,
            tone: ZxMessageTone.danger,
          ),
          const SizedBox(height: 12),
        ],
        ZxButton(
          key: const Key('login-submit'),
          label: isBusy
              ? l10n.loggingIn
              : uiText(context, zh: '西电统一身份认证登录', en: 'Sign in with Xidian'),
          icon: Icons.badge_outlined,
          loading: isBusy,
          expand: true,
          onPressed: isBusy ? null : onLogin,
        ),
        const SizedBox(height: 10),
        Text(
          uiText(
            context,
            zh: '将跳转到学校统一身份认证页面，用学号和密码登录',
            en: 'You will continue to Xidian’s sign-in page and use your student ID and password.',
          ),
          textAlign: TextAlign.center,
          style: ZxType.caption.copyWith(color: t.text3),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: t.line),
        const SizedBox(height: 12),
        _AgreementRow(
          agreed: agreed,
          showHint: agreementHint,
          nudges: nudges,
          onChanged: onAgreedChanged,
        ),
        // Only the separate admin bundle carries the backoffice; see
        // AppConfig.adminConsoleEnabled.
        if (AppConfig.adminConsoleEnabled) ...<Widget>[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: isBusy ? null : onAdminLogin,
              child: Text(l10n.adminLogin),
            ),
          ),
        ],
      ],
    );
  }
}

/// 我已阅读并同意《用户协议》和《隐私政策》. The links open the documents
/// without toggling the checkbox. Signing in without consent raises a
/// bubble above it, outlines it in danger and shakes it once.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.agreed,
    required this.showHint,
    required this.nudges,
    required this.onChanged,
  });

  final bool agreed;
  final bool showHint;
  final int nudges;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    Widget link(String zh, String en, Widget page) => InkWell(
      onTap: () => open(page),
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
        if (showHint)
          Container(
            key: const Key('login-agreement-hint'),
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
          key: ValueKey<int>(nudges),
          tween: Tween<double>(begin: nudges == 0 ? 1 : 0, end: 1),
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
                  key: const Key('login-agreement'),
                  value: agreed,
                  onChanged: (bool? value) => onChanged(value ?? false),
                  side: BorderSide(
                    color: showHint ? t.danger : t.lineStrong,
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
                      onTap: () => onChanged(!agreed),
                      child: Text(
                        uiText(
                          context,
                          zh: '我已阅读并同意',
                          en: 'I have read and accept the ',
                        ),
                        style: plain,
                      ),
                    ),
                    link('《用户协议》', 'Terms', const TermsOfServicePage()),
                    Text(
                      uiText(context, zh: '和', en: ' and '),
                      style: plain,
                    ),
                    link('《隐私政策》', 'Privacy Policy', const PrivacyPolicyPage()),
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

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget link(String zh, String en, Widget page) => TextButton(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: t.text2,
      ),
      child: Text(
        uiText(context, zh: zh, en: en),
        style: ZxType.caption,
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        link('用户协议', 'Terms', const TermsOfServicePage()),
        link('隐私政策', 'Privacy', const PrivacyPolicyPage()),
        link('社区规范', 'Guidelines', const CommunityGuidelinesPage()),
      ],
    );
  }
}
