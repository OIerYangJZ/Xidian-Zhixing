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

/// 嵌套在树洞 [MaterialApp.router] 内的 XDYou 根界面（内含独立 [MaterialApp]）。
Widget buildXdyouApp() => MyApp(isFirst: xdyouIsFirstLogin());
