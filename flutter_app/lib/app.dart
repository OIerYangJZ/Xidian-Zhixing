import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/config/app_config.dart';
import 'core/state/app_locale_store.dart';
import 'core/state/app_theme_store.dart';
import 'features/admin/admin_portal_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/banned_account_page.dart';
import 'features/auth/login_page.dart';
import 'features/common/access_state_page.dart';
import 'features/legal/privacy_policy_page.dart';
import 'features/legal/community_guidelines_page.dart';
import 'features/legal/report_guidelines_page.dart';
import 'features/legal/terms_of_service_page.dart';
import 'l10n/generated/app_localizations.dart';
import 'widgets/home_shell.dart';

class XduTreeholeApp extends StatefulWidget {
  const XduTreeholeApp({super.key});

  @override
  State<XduTreeholeApp> createState() => _XduTreeholeAppState();
}

class _XduTreeholeAppState extends State<XduTreeholeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<SessionChange> _sessionChanges;

  @override
  void initState() {
    super.initState();
    _sessionChanges = AuthStore.instance.sessionChanges.listen(
      _onSessionChange,
    );
  }

  @override
  void dispose() {
    _sessionChanges.cancel();
    super.dispose();
  }

  /// No router guard here, so what the server does to the session moves the
  /// whole stack: a dead session to sign-in, a ban to the appeal screen.
  void _onSessionChange(SessionChange change) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    final Widget page = switch (change) {
      SessionChange.expired => const LoginPage(),
      SessionChange.banned => bannedAccountPage(),
      SessionChange.unbanned => const HomeShell(),
    };
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => page),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        AppLocaleStore.instance,
        AppThemeStore.instance,
      ]),
      builder: (BuildContext context, Widget? child) {
        final Locale locale = AppLocaleStore.instance.locale;
        final String themeKey = AppThemeStore.instance.themeKey;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.designSystemFor(
            themeKey: themeKey,
            brightness: Brightness.light,
          ),
          darkTheme: AppTheme.designSystemFor(
            themeKey: themeKey,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          locale: locale,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
          onGenerateRoute: _onGenerateRoute,
          onUnknownRoute: (RouteSettings settings) => MaterialPageRoute<void>(
            builder: (_) => const AccessStatePage.notFound(),
            settings: settings,
          ),
        );
      },
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? '/';

    if (routeName == '/') {
      return MaterialPageRoute<void>(
        builder: (_) => _initialPage(),
        settings: settings,
      );
    }

    if (routeName == '/terms') {
      return MaterialPageRoute<void>(
        builder: (_) => const TermsOfServicePage(),
        settings: settings,
      );
    }
    if (routeName == '/privacy') {
      return MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyPage(),
        settings: settings,
      );
    }
    if (routeName == '/guidelines') {
      return MaterialPageRoute<void>(
        builder: (_) => const CommunityGuidelinesPage(),
        settings: settings,
      );
    }
    if (routeName == '/report-guidelines') {
      return MaterialPageRoute<void>(
        builder: (_) => const ReportGuidelinesPage(),
        settings: settings,
      );
    }
    return null;
  }

  static Widget _initialPage() {
    if (AuthStore.instance.isAuthenticated) {
      // A banned session can reach only the appeal endpoints, so building the
      // shell would render a screen whose every request comes back 403.
      if (AuthStore.instance.isBanned) {
        return bannedAccountPage();
      }
      return const HomeShell();
    }
    if (AppConfig.adminConsoleEnabled &&
        AdminAuthStore.instance.isAuthenticated) {
      return const AdminPortalPage();
    }
    return const LoginPage();
  }
}

/// The ban screen on the web: signing out goes back to the login page.
Widget bannedAccountPage() => Builder(
  builder: (BuildContext context) => BannedAccountPage(
    onSignedOut: () => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false,
    ),
  ),
);
