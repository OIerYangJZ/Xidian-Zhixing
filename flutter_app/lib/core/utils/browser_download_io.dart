import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

Future<bool> triggerBrowserDownload(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  // The url comes from the server-provided release manifest.  On Android
  // launchUrl will happily hand an `intent://` or `file://` url to the system,
  // which can start arbitrary components, so restrict it to plain web urls.
  if (!AppConfig.isWebUrl(trimmed)) {
    return false;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
