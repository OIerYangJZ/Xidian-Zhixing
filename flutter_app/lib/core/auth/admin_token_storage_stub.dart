/// Non-web builds keep the admin token in the Keychain / Android Keystore, so
/// this side of the conditional import is never used.
String? readAdminToken(String key) => null;

void writeAdminToken(String key, String value) {}

void clearAdminToken(String key) {}
