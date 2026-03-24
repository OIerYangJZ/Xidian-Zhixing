import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/mobile_config.dart';
import 'core/theme/mobile_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/state/mobile_providers.dart';
import '../lib/core/auth/auth_store.dart';
import '../lib/core/auth/admin_auth_store.dart';
import '../lib/core/emoji/emoji_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储
  await AuthStore.instance.init();
  await AdminAuthStore.instance.init();
  await EmojiSettingsStore.instance.init();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 设置竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: XduTreeholeMobileApp(),
    ),
  );
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
