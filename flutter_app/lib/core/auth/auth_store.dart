import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'xdu_treehole_auth_token';

  /// On mobile the session token lives in the Keychain / Android Keystore
  /// instead of SharedPreferences, which is a world-readable plist on iOS
  /// backups and a plain XML file on a rooted Android device.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// flutter_secure_storage on web is just localStorage with a WebCrypto
  /// wrapper whose key also lives in localStorage, so it buys nothing there.
  /// Web keeps SharedPreferences; the real defence for web is the backend's
  /// session TTL plus HTTPS.
  static bool get _useSecureStorage => !kIsWeb;

  SharedPreferences? _prefs;
  String? _token;
  UserProfile? _currentUser;

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  UserProfile? get currentUser => _currentUser;

  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_useSecureStorage) {
      _token = _prefs?.getString(_tokenKey);
      notifyListeners();
      return;
    }

    String? token;
    try {
      token = await _secureStorage.read(key: _tokenKey);
    } catch (_) {
      // Keystore unavailable (e.g. corrupted keys after a restore): treat as
      // logged out rather than crashing at startup.
      token = null;
    }

    // One-time migration off the old plaintext location.
    final String? legacyToken = _prefs?.getString(_tokenKey);
    if ((token == null || token.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty) {
      token = legacyToken;
      try {
        await _secureStorage.write(key: _tokenKey, value: legacyToken);
      } catch (_) {
        // Keep the in-memory token; it will be re-written on next save.
      }
    }
    if (legacyToken != null) {
      await _prefs?.remove(_tokenKey);
    }

    _token = token;
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    if (_useSecureStorage) {
      try {
        await _secureStorage.write(key: _tokenKey, value: token);
      } catch (_) {
        // Fall through: the session still works for this run.
      }
    } else {
      await _prefs?.setString(_tokenKey, token);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _currentUser = null;
    await _prefs?.remove(_tokenKey);
    if (_useSecureStorage) {
      try {
        await _secureStorage.delete(key: _tokenKey);
      } catch (_) {
        // Nothing more to do; the in-memory token is already gone.
      }
    }
    notifyListeners();
  }
}
