import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shared_colors.dart';

class AppThemeStore extends ChangeNotifier {
  AppThemeStore._();

  static final AppThemeStore instance = AppThemeStore._();
  static const String _storageKey = 'treehole_theme_key';

  String _themeKey = AppColorThemes.defaultKey;

  String get themeKey => _themeKey;

  Future<void> init() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? storedKey = preferences.getString(_storageKey);
    final String resolvedKey = AppColorThemes.resolveStoredKey(storedKey);
    _themeKey = resolvedKey;
    if (storedKey != null && storedKey != resolvedKey) {
      await preferences.setString(_storageKey, resolvedKey);
    }
  }

  Future<void> setThemeKey(String key) async {
    if (!AppColorThemes.isSupported(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported color theme');
    }
    if (_themeKey == key) {
      return;
    }
    _themeKey = key;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, key);
    notifyListeners();
  }
}
