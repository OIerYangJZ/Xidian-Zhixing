import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:watermeter/controller/theme_controller.dart';

import '../l10n/generated/app_localizations.dart';
import 'core/config/mobile_config.dart';
import 'core/navigation/app_router.dart';
import 'core/state/app_settings_store.dart';
import 'core/state/mobile_providers.dart';
import 'core/theme/mobile_theme.dart';
import 'integrations/xdyou_bootstrap.dart';

Future<void> prepareMobileApp() async {
  await AppSettingsStore.instance.init();
  await ensureXdyouEmbedInitialized();
  await syncTreeholeThemeToXdyou();
  await syncTreeholeLanguageToXdyou();
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

    return GetBuilder<ThemeController>(
      builder: (themeCtrl) => MaterialApp.router(
        title: '西电树洞',
        debugShowCheckedModeBanner: false,
        theme: MobileTheme.lightTheme,
        darkTheme: MobileTheme.darkTheme,
        themeMode: settings.themeMode,
        locale: settings.locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          themeCtrl.getI18nDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter,
      ),
    );
  }
}
