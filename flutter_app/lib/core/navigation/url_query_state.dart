import 'url_query_state_stub.dart'
    if (dart.library.html) 'url_query_state_web.dart' as impl;

String? currentPostIdFromUrl() => impl.currentPostIdFromUrl();

void setPostIdOnUrl(String? postId) => impl.setPostIdOnUrl(postId);

String? takeQueryParameterFromUrl(String key) => impl.takeQueryParameterFromUrl(key);

/// Post id when the page was opened at a shared /p/<id> link.
String? currentPostLinkId() => impl.currentPostLinkId();

/// Resets the path to / once the linked post has been opened, so a reload
/// does not open it again. Query and fragment are kept.
void clearPostLinkFromUrl() => impl.clearPostLinkFromUrl();
