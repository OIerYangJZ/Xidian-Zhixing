import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shared_colors.dart';

class AppThemeStore extends ChangeNotifier {
  AppThemeStore._();

  static final AppThemeStore instance = AppThemeStore._();
  static const String _storageKey = 'treehole_theme_key';
  static const String _modeStorageKey = 'treehole_theme_mode';

  String _themeKey = AppColorThemes.defaultKey;
  ThemeMode _mode = ThemeMode.light;

  String get themeKey => _themeKey;
  ThemeMode get mode => _mode;

  Future<void> init() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? storedKey = preferences.getString(_storageKey);
    _mode = preferences.getString(_modeStorageKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    final String resolvedKey = AppColorThemes.resolveStoredKey(storedKey);
    _themeKey = resolvedKey;
    if (storedKey != null && storedKey != resolvedKey) {
      await preferences.setString(_storageKey, resolvedKey);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _modeStorageKey,
      _mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
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
