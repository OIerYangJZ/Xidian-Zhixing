import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';
import 'package:watermeter/main.dart' show MyApp;
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/network_session.dart' as repo_general;
import 'package:watermeter/repository/notification/notification_registrar.dart';
import 'package:watermeter/repository/preference.dart' as wm_pref;
import 'package:watermeter/controller/theme_controller.dart';
import 'package:get/get.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

bool _xdyouEmbedReady = false;

/// 与 XDYou 独立应用 [main] 中一致的本地存储与 PackageInfo 初始化（嵌入树洞 Tab 前必须调用）。
Future<void> ensureXdyouEmbedInitialized() async {
  if (_xdyouEmbedReady) return;
  repo_general.supportPath = await getApplicationSupportDirectory();
  const opts = SharedPreferencesOptions();
  final legacy = await SharedPreferences.getInstance();
  if (legacy.getKeys().isNotEmpty) {
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: legacy,
      sharedPreferencesAsyncOptions: opts,
      migrationCompletedKey: 'pdaMigrationCompleted',
    );
  }
  wm_pref.prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  wm_pref.packageInfo = await PackageInfo.fromPlatform();

  // 初始化 GetX ThemeController（必须在 MyApp 构建前完成，否则 i18n 无法加载）
  if (!Get.isRegistered<ThemeController>()) {
    Get.put(ThemeController());
  }

  _xdyouEmbedReady = true;
  log.info('XDYou embed: storage ready');
}

/// 课程提醒等本地通知（与独立 XDYou 启动流程一致）。
Future<void> initXdyouNotificationServices() async {
  try {
    await NotificationServiceRegistrar().initializeAllServices();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final services = NotificationServiceRegistrar().getAllServices();
      await Future.wait(
        services.map((s) => s.handleAppLaunchFromNotification()),
      );
    });
  } catch (e, st) {
    log.error('XDYou embed: notification init failed: $e', e, st);
  }
}

bool xdyouIsFirstLogin() {
  final u = wm_pref.getString(wm_pref.Preference.idsAccount);
  final p = wm_pref.getString(wm_pref.Preference.idsPassword);
  return u.isEmpty || p.isEmpty;
}

/// 同步树洞账号密码到 XDYou 登录系统
Future<void> syncTreeholeCredentialsToXdyou(String username, String password) async {
  await ensureXdyouEmbedInitialized();
  wm_pref.setString(wm_pref.Preference.idsAccount, username);
  wm_pref.setString(wm_pref.Preference.idsPassword, password);
  log.info('XDYou: synced credentials from treehole');
}

/// 嵌套在树洞 [MaterialApp.router] 内的 XDYou 根界面（内含独立 [MaterialApp]）。
/// 如果树洞已登录，则跳过 XDYou 的登录页面。
Widget buildXdyouApp() {
  final treeHoleLoggedIn = AuthStore.instance.isAuthenticated;
  return MyApp(isFirst: !treeHoleLoggedIn && xdyouIsFirstLogin());
}
