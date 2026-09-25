import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/shared_colors.dart';

/// 树洞移动端应用级设置（主题、语言）的持久化管理。
/// 单例，通过 AppSettingsStore.instance 访问。
class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  SharedPreferences? _prefs;

  static const String _brightnessKey =
      'treehole_brightness'; // ThemeMode.index: 0=system, 1=light, 2=dark
  static const String _localeKey = 'treehole_localization'; // 'zh_CN', 'en_US'
  static const String _legacyLocaleKey = 'treehole_locale';
  static const String _themeKeyStorageKey = 'treehole_theme_key';

  /// Follows the system unless the user picks light or dark.
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  String _themeKey = AppColorThemes.defaultKey;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  String get themeKey => _themeKey;

  /// 应用启动时调用，从 SharedPreferences 恢复持久化状态。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Nothing ever wrote this key before, so an unset value means system.
    final int storedMode = _prefs!.getInt(_brightnessKey) ?? 0;
    _themeMode = ThemeMode.values[storedMode.clamp(0, 2)];
    final String? storedThemeKey = _prefs!.getString(_themeKeyStorageKey);
    _themeKey = AppColorThemes.resolveStoredKey(storedThemeKey);
    if (storedThemeKey != null && storedThemeKey != _themeKey) {
      await _prefs!.setString(_themeKeyStorageKey, _themeKey);
    }
    final String loc =
        _prefs!.getString(_localeKey) ??
        _prefs!.getString(_legacyLocaleKey) ??
        'zh_CN';
    _locale = _parseLocaleCode(loc);
    notifyListeners();
  }

  /// 设置深浅模式（跟随系统 / 浅色 / 深色）并持久化。
  Future<void> setBrightness(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_brightnessKey, mode.index);
    notifyListeners();
  }

  /// 设置主题配色并持久化。
  Future<void> setThemeKey(String key) async {
    if (!AppColorThemes.isSupported(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported color theme');
    }
    if (_themeKey == key) {
      return;
    }
    _themeKey = key;
    await _prefs?.setString(_themeKeyStorageKey, key);
    notifyListeners();
  }

  /// 设置语言并持久化。
  Future<void> setLocale(Locale loc) async {
    _locale = _normalizeLocale(loc);
    final code = _storageLocaleCode(_locale!);
    await _prefs?.setString(_localeKey, code);
    await _prefs?.setString(_legacyLocaleKey, code);
    notifyListeners();
  }

  Locale _normalizeLocale(Locale locale) {
    if (locale.languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('zh', 'CN');
  }

  Locale _parseLocaleCode(String raw) {
    final String code = raw.trim();
    switch (code) {
      case 'zh_TW':
      case 'zh_Hant':
        return const Locale('zh', 'CN');
      case 'en':
      case 'en_US':
        return const Locale('en');
      case 'zh':
      case 'zh_CN':
      default:
        return const Locale('zh', 'CN');
    }
  }

  String _storageLocaleCode(Locale locale) {
    if (locale.languageCode == 'en') {
      return 'en_US';
    }
    return 'zh_CN';
  }
}
