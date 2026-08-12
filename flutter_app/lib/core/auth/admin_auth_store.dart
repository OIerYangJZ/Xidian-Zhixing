import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminAuthStore {
  AdminAuthStore._();

  static final AdminAuthStore instance = AdminAuthStore._();

  static const String _tokenKey = 'xdu_treehole_admin_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static bool get _useSecureStorage => !kIsWeb;

  SharedPreferences? _prefs;
  String? _token;

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_useSecureStorage) {
      _token = _prefs?.getString(_tokenKey);
      return;
    }
    _token = await _secureStorage.read(key: _tokenKey);
    final String? legacyToken = _prefs?.getString(_tokenKey);
    if ((_token == null || _token!.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      _token = legacyToken;
    }
    await _prefs?.remove(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    if (_useSecureStorage) {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _prefs?.remove(_tokenKey);
      return;
    }
    await _prefs?.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    _token = null;
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _tokenKey);
    }
    await _prefs?.remove(_tokenKey);
  }
}
