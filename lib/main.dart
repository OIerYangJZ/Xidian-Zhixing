import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';

import 'app.dart';
import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/emoji/emoji_settings_store.dart';
import 'package:get/get.dart';
import 'package:watermeter/controller/theme_controller.dart';

import 'mobile/core/config/mobile_config.dart';
import 'mobile/core/theme/mobile_theme.dart';
import 'mobile/core/navigation/app_router.dart';
import 'mobile/core/state/app_settings_store.dart';
import 'mobile/core/state/mobile_providers.dart';
import 'mobile/integrations/xdyou_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.init();
  await AdminAuthStore.instance.init();
  await EmojiSettingsStore.instance.init();

  if (kIsWeb) {
    runApp(const ProviderScope(child: XduTreeholeApp()));
  } else {
    await AppSettingsStore.instance.init();
    // 提前初始化 XDYou ThemeController，使 FlutterI18nDelegate 在对话框
    // （useRootNavigator:true）中也能被外层 MaterialApp.router 提供。
    await ensureXdyouEmbedInitialized();
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
    runApp(const ProviderScope(child: XduTreeholeMobileApp()));
  }
}

class XduTreeholeMobileApp extends ConsumerWidget {
  const XduTreeholeMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    // GetBuilder 监听 ThemeController（XDYou 的 i18n 控制器），确保
    // FlutterI18nDelegate 始终注册在外层 MaterialApp.router 的
    // localizationsDelegates 中，从而使通过 useRootNavigator:true
    // 弹出的 XDYou 对话框也能访问到 FlutterI18n 本地化数据。
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
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'Hant'),
          Locale('en', 'US'),
        ],
        routerConfig: appRouter,
      ),
    );
  }
}
