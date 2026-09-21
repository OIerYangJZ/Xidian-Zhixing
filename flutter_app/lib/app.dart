import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/config/app_config.dart';
import 'core/state/app_locale_store.dart';
import 'core/state/app_theme_store.dart';
import 'features/admin/admin_portal_page.dart';
import 'features/admin/admin_login_page.dart';
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

class XduTreeholeApp extends StatelessWidget {
  const XduTreeholeApp({super.key});

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
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightThemeFor(locale, themeKey: themeKey),
          darkTheme: AppTheme.darkThemeFor(locale, themeKey: themeKey),
          themeMode: AppThemeStore.instance.mode,
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
    if (routeName == '/admin' && AppConfig.adminConsoleEnabled) {
      return MaterialPageRoute<void>(builder: (_) => const AdminPortalPage());
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
    if (AppConfig.adminConsoleEnabled) {
      return AdminAuthStore.instance.isAuthenticated
          ? const AdminPortalPage()
          : const AdminLoginPage();
    }
    if (AuthStore.instance.isAuthenticated) {
      // A banned session can reach only the appeal endpoints, so building the
      // shell would render a screen whose every request comes back 403.
      if (AuthStore.instance.isBanned) {
        return const BannedAccountPage();
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
