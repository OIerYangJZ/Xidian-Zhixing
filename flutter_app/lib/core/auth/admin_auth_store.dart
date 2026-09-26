import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_token_storage.dart' as web_storage;

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
  final StreamController<void> _expired = StreamController<void>.broadcast();

  /// Admin sessions live in the backend's memory, so a restart or deploy ends
  /// them; the console returns to sign-in when that happens.
  Stream<void> get sessionExpired => _expired.stream;

  /// The server answered 401 to a request carrying this admin session.
  Future<void> expireSession() async {
    if (!isAuthenticated) {
      return;
    }
    await clear();
    _expired.add(null);
  }

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_useSecureStorage) {
      // Web keeps the backoffice token in sessionStorage — see
      // admin_token_storage_web.dart for why it is not SharedPreferences.
      _token = web_storage.readAdminToken(_tokenKey);
      // Purge any token an older build left in localStorage.
      await _prefs?.remove(_tokenKey);
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
    web_storage.writeAdminToken(_tokenKey, token);
    await _prefs?.remove(_tokenKey);
  }

  Future<void> clear() async {
    _token = null;
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _tokenKey);
    } else {
      web_storage.clearAdminToken(_tokenKey);
    }
    await _prefs?.remove(_tokenKey);
  }
}
