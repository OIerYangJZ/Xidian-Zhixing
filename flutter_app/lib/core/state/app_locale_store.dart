import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleStore extends ChangeNotifier {
  AppLocaleStore._();

  static final AppLocaleStore instance = AppLocaleStore._();
  static const String _storageKey = 'app_locale';

  Locale _locale = const Locale('zh', 'CN');

  Locale get locale => _locale;

  Future<void> init() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String saved = preferences.getString(_storageKey) ?? 'zh';
    _locale = saved == 'en' ? const Locale('en') : const Locale('zh', 'CN');
  }

  Future<void> setLocale(Locale locale) async {
    final Locale normalized = locale.languageCode == 'en'
        ? const Locale('en')
        : const Locale('zh', 'CN');
    if (_locale == normalized) {
      return;
    }
    _locale = normalized;
    notifyListeners();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, normalized.languageCode);
  }

  Future<void> toggle() {
    return setLocale(
      _locale.languageCode == 'en'
          ? const Locale('zh', 'CN')
          : const Locale('en'),
    );
  }
}
