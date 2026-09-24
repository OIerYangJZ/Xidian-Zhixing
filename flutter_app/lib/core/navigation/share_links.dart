import '../config/app_config.dart';

enum ShareLinkKind { post, user }

/// A public short link: https://<site>/p/<postId> or https://<site>/u/<userId>.
///
/// Every client resolves the same URL: the web app opens it, the Android app
/// claims /p/ and /u/ through an App Links intent filter, and the mini
/// program receives it from a scanned QR code. Keep the format in step with
/// miniprogram/utils/share_links.js.
class ShareLink {
  const ShareLink.post(this.id) : kind = ShareLinkKind.post;
  const ShareLink.user(this.id) : kind = ShareLinkKind.user;

  final ShareLinkKind kind;
  final String id;

  static final RegExp _path = RegExp(r'^/([pu])/([A-Za-z0-9_-]{1,64})/?$');

  static ShareLink? parsePath(String path) {
    final RegExpMatch? match = _path.firstMatch(path);
    if (match == null) {
      return null;
    }
    final String id = match.group(2)!;
    return match.group(1) == 'p' ? ShareLink.post(id) : ShareLink.user(id);
  }

  String get path =>
      '/${kind == ShareLinkKind.post ? 'p' : 'u'}/${Uri.encodeComponent(id)}';

  String get url => '${AppConfig.publicSiteOrigin}$path';

  @override
  bool operator ==(Object other) =>
      other is ShareLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => path;
}
