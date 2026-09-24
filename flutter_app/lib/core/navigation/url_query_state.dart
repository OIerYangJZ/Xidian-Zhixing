import 'share_links.dart';
import 'url_query_state_stub.dart'
    if (dart.library.html) 'url_query_state_web.dart' as impl;

String? currentPostIdFromUrl() => impl.currentPostIdFromUrl();

void setPostIdOnUrl(String? postId) => impl.setPostIdOnUrl(postId);

String? takeQueryParameterFromUrl(String key) => impl.takeQueryParameterFromUrl(key);

/// The shared /p/<id> or /u/<id> link this page was opened at, if any.
ShareLink? currentShareLink() => impl.currentShareLink();

/// Resets the path to / once the link has been opened, so a reload does not
/// open it again. Query and fragment are kept.
void clearShareLinkFromUrl() => impl.clearShareLinkFromUrl();
