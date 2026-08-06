import 'package:web/web.dart' as web;

import '../config/app_config.dart';

Future<bool> triggerBrowserDownload(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  // The url comes from the server-provided release manifest and lands directly
  // in an anchor href, so a javascript:/data: value would execute on our own
  // origin.  Only absolute http(s) urls and same-origin paths may proceed.
  final bool isSameOriginPath =
      trimmed.startsWith('/') && !trimmed.startsWith('//');
  if (!isSameOriginPath && !AppConfig.isWebUrl(trimmed)) {
    return false;
  }
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = trimmed
    ..target = '_self'
    ..rel = 'noopener'
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
