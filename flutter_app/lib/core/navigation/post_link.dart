import '../config/app_config.dart';

// Public short link for one post: https://<site>/p/<postId>.
//
// Every client resolves the same URL: the web app opens the post, the Android
// app claims /p/ through an App Links intent filter, and the mini program
// receives it from a scanned QR code. Keep the format in step with
// miniprogram/utils/post_link.js.
final RegExp _postLinkPath = RegExp(r'^/p/([A-Za-z0-9_-]{1,64})/?$');

String? postIdFromLinkPath(String path) =>
    _postLinkPath.firstMatch(path)?.group(1);

String postLinkPath(String postId) => '/p/${Uri.encodeComponent(postId)}';

String postShareLink(String postId) =>
    '${AppConfig.publicSiteOrigin}${postLinkPath(postId)}';
