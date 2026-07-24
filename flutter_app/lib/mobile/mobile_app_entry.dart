import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/generated/app_localizations.dart';
import 'core/config/mobile_config.dart';
import 'core/navigation/app_router.dart';
import 'core/state/app_settings_store.dart';
import 'core/state/mobile_providers.dart';
import 'core/theme/mobile_theme.dart';
import 'features/update/app_update_bootstrap.dart';

Future<void> prepareMobileApp() async {
  await AppSettingsStore.instance.init();
  if (MobileConfig.debugMode) {
    debugPrint('[mobile] API base: ${MobileConfig.apiBaseUrl}');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class XduTreeholeMobileApp extends ConsumerWidget {
  const XduTreeholeMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: '西电知行',
      debugShowCheckedModeBanner: false,
      theme: MobileTheme.getThemeData(settings.themeKey),
      themeMode: ThemeMode.light,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppUpdateBootstrap(child: child ?? const SizedBox.shrink()),
    );
  }
}
