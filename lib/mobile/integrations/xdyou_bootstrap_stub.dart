import 'package:flutter/widgets.dart';

Future<void> ensureXdyouEmbedInitialized() async {}

Future<void> initXdyouNotificationServices() async {}

bool xdyouIsFirstLogin() => true;

Future<void> syncTreeholeCredentialsToXdyou(
  String username,
  String password,
) async {}

Future<void> syncTreeholeThemeToXdyou() async {}

Future<void> syncTreeholeLanguageToXdyou() async {}

Future<void> syncAllToXdyou(String username, String password) async {}

Widget buildXdyouApp() => const SizedBox.shrink();

Future<bool> maybeHandleXdyouBackPress() async => false;

abstract class TreeholeSharedKeys {
  static const String brightness   = 'treehole_brightness';
  static const String colorSeed    = 'treehole_color_seed';
  static const String localization = 'treehole_localization';
}

typedef _SyncThemeFn = Future<void> Function();
typedef _SyncLocaleFn = Future<void> Function();

_SyncThemeFn? _syncThemeToXdyou;
_SyncLocaleFn? _syncLocaleToXdyou;

void registerXdyouSyncFunctions({
  required _SyncThemeFn syncTheme,
  required _SyncLocaleFn syncLocale,
}) {
  _syncThemeToXdyou = syncTheme;
  _syncLocaleToXdyou = syncLocale;
}

Future<void> callSyncThemeToXdyou() async {
  try {
    await _syncThemeToXdyou?.call();
  } catch (_) {}
}

Future<void> callSyncLocaleToXdyou() async {
  try {
    await _syncLocaleToXdyou?.call();
  } catch (_) {}
}
