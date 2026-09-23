/// Where to go once signed in: the `from` location the router guard recorded
/// when it sent the user to log in, if it is a plain in-app path, otherwise
/// home.
String loginReturnLocation(Uri loginUri) {
  final String from = (loginUri.queryParameters['from'] ?? '').trim();
  if (!from.startsWith('/') ||
      from.startsWith('//') ||
      from.startsWith('/auth')) {
    return '/';
  }
  return from;
}
