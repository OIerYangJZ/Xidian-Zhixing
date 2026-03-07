import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'xdu_treehole_auth_token';
  SharedPreferences? _prefs;
  String? _token;

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs?.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _prefs?.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    _token = null;
    await _prefs?.remove(_tokenKey);
  }
}
