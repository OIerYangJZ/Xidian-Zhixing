import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/emoji/emoji_settings_store.dart';
import 'mobile/core/config/mobile_config.dart';
import 'mobile/core/theme/mobile_theme.dart';
import 'mobile/core/navigation/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.init();
  await AdminAuthStore.instance.init();
  await EmojiSettingsStore.instance.init();

  if (kIsWeb) {
    runApp(const ProviderScope(child: XduTreeholeApp()));
  } else {
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
    return MaterialApp.router(
      title: '西电树洞',
      debugShowCheckedModeBanner: false,
      theme: MobileTheme.lightTheme,
      darkTheme: MobileTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
