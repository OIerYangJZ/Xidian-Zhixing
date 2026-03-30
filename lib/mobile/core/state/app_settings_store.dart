import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xdu_treehole_web/mobile/integrations/xdyou_sync_bridge.dart';

/// 树洞移动端应用级设置（主题、语言）的持久化管理。
/// 单例，通过 AppSettingsStore.instance 访问。
class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  SharedPreferences? _prefs;

  static const String _brightnessKey = 'treehole_brightness'; // ThemeMode.index: 0=system, 1=light, 2=dark
  static const String _localeKey     = 'treehole_locale';     // 'zh_CN', 'zh_TW', 'en_US'

  ThemeMode _themeMode = ThemeMode.light;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale     => _locale;

  /// 应用启动时调用，从 SharedPreferences 恢复持久化状态。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs!.getInt(_brightnessKey) ?? 1];
    final loc = _prefs!.getString(_localeKey);
    if (loc != null && loc.isNotEmpty) {
      final parts = loc.split('_');
      _locale = parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    } else {
      _locale = const Locale('zh', 'CN');
    }
    notifyListeners();
  }

  /// 设置主题亮度并持久化，同时同步到 XDYou。
  Future<void> setBrightness(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_brightnessKey, mode.index);
    notifyListeners();
    try {
      await callSyncThemeToXdyou();
    } catch (_) {}
  }

  /// 设置语言并持久化，同时同步到 XDYou。
  Future<void> setLocale(Locale loc) async {
    _locale = loc;
    final code = '${loc.languageCode}_${loc.countryCode ?? ''}';
    await _prefs?.setString(_localeKey, code);
    notifyListeners();
    try {
      await callSyncLocaleToXdyou();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // 以下 getter 暴露给 xdyou_bootstrap.dart，用于同步到 XDYou SharedPreferences
  // -------------------------------------------------------------------------

  /// XDYou brightness 对应值：0=system, 1=light, 2=dark
  int get xdyouBrightness => _themeMode.index;

  /// XDYou colorSeed：主 App 暂不使用，固定为 0
  int get xdyouColorSeed => 0;

  /// XDYou localization 对应字符串，如 'zh_CN'
  String get xdyouLocalization {
    if (_locale == null) return 'zh_CN';
    return '${_locale!.languageCode}_${_locale!.countryCode ?? ''}';
  }
}
