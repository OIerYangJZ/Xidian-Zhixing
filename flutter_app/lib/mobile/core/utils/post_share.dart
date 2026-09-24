import 'package:flutter/services.dart';

import 'package:xdu_treehole_web/core/navigation/share_links.dart';

Future<void> copyPostShareLink(String postId) {
  return Clipboard.setData(ClipboardData(text: ShareLink.post(postId).url));
}
