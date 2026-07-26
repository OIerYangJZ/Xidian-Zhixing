import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shared_colors.dart';

/// Persisted Web appearance. Every future visual preset is selected here and
/// supplied to [AppTheme], never assembled by a feature page.
class WebThemeStore extends ChangeNotifier {
  WebThemeStore._();

  static final WebThemeStore instance = WebThemeStore._();
  static const String _presetKey = 'web_theme_preset';
  static const String _modeKey = 'web_theme_mode';

  AppThemePreset _preset = AppThemePresets.inkVermilion;
  ThemeMode _themeMode = ThemeMode.system;

  AppThemePreset get preset => _preset;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    _preset = AppThemePresets.byId(
      preferences.getString(_presetKey) ?? AppThemePresets.inkVermilion.id,
    );
    final int? storedMode = preferences.getInt(_modeKey);
    if (storedMode != null &&
        storedMode >= 0 &&
        storedMode < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[storedMode];
    }
  }

  Future<void> setPreset(String presetId) async {
    final AppThemePreset next = AppThemePresets.byId(presetId);
    if (next.id == _preset.id) {
      return;
    }
    _preset = next;
    notifyListeners();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_presetKey, next.id);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_modeKey, mode.index);
  }
}
