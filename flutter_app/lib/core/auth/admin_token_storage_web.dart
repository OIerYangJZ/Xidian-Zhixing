// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// sessionStorage rather than localStorage for the backoffice token.
///
/// SharedPreferences (and flutter_secure_storage) both land in localStorage on
/// web: persistent, shared by every tab on the origin, and sitting next to the
/// ordinary user session. A moderator token is the highest-value credential the
/// app holds, so it is scoped to the one tab that logged in and dies when that
/// tab closes.
String? readAdminToken(String key) {
  final String? value = html.window.sessionStorage[key];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

void writeAdminToken(String key, String value) {
  html.window.sessionStorage[key] = value;
}

void clearAdminToken(String key) {
  html.window.sessionStorage.remove(key);
}
