import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';

/// What the server did to the session, as opposed to the user signing in or
/// out. The web app has no router guard, so it navigates on these.
enum SessionChange {
  /// 401: the session expired or was revoked. Local auth is already cleared.
  expired,

  /// 403 with accountState "banned".
  banned,

  /// The ban screen found the ban lifted.
  unbanned,
}

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'xdu_treehole_auth_token';

  /// Survives a reload, so a banned session opens on the ban screen instead
  /// of a shell whose first request comes back 403.
  static const String _bannedKey = 'xdu_treehole_account_banned';

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
  bool _banned = false;
  bool _sessionExpiredNotice = false;
  final StreamController<SessionChange> _sessionChanges =
      StreamController<SessionChange>.broadcast();

  /// Bumped whenever whose data the app may show changes: a new token,
  /// signing out, an expired session, a ban or its lifting. Per-account
  /// state (feed, messages, notifications, …) is rebuilt from scratch on
  /// every bump — see accountEpochProvider.
  final ValueNotifier<int> accountEpoch = ValueNotifier<int>(0);

  void _bumpAccountEpoch() {
    accountEpoch.value += 1;
  }

  Stream<SessionChange> get sessionChanges => _sessionChanges.stream;

  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// A banned account holds a real session, but the server answers 403 to
  /// everything except signing out, reading this profile and the appeal
  /// endpoints. Routing reads this so the shell is never built for a session
  /// whose every request would be refused.
  bool get isBanned => _banned;

  UserProfile? get currentUser => _currentUser;

  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
    if (user == null || user.banned == _banned) {
      return;
    }
    // The profile is the server's word too: a ban (or its lifting) learned
    // here moves the app just as a refused request does.
    if (user.banned) {
      banFromServer();
    } else {
      liftBan();
    }
  }

  void setBanned(bool banned) {
    if (_banned == banned) {
      return;
    }
    _banned = banned;
    if (banned) {
      unawaited(_prefs?.setBool(_bannedKey, true));
    } else {
      unawaited(_prefs?.remove(_bannedKey));
    }
    _bumpAccountEpoch();
    notifyListeners();
  }

  /// The server answered 401 to a request carrying this session.
  Future<void> expireSession() async {
    if (!isAuthenticated) {
      return;
    }
    _sessionExpiredNotice = true;
    await clear();
    _sessionChanges.add(SessionChange.expired);
  }

  /// Read once by the login page: 登录已失效，请重新登录.
  bool takeSessionExpiredNotice() {
    final bool notice = _sessionExpiredNotice;
    _sessionExpiredNotice = false;
    return notice;
  }

  /// The server refused a request because the account is banned.
  void banFromServer() {
    if (_banned || !isAuthenticated) {
      return;
    }
    setBanned(true);
    _sessionChanges.add(SessionChange.banned);
  }

  /// The ban screen learned from the server that the ban is gone.
  void liftBan() {
    if (!_banned) {
      return;
    }
    setBanned(false);
    _sessionChanges.add(SessionChange.unbanned);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _banned = _prefs?.getBool(_bannedKey) ?? false;
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
    if (_token != token) {
      _bumpAccountEpoch();
    }
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
    _banned = false;
    _bumpAccountEpoch();
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_bannedKey);
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
