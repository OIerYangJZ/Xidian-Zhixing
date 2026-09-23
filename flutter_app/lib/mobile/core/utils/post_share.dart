import 'package:flutter/services.dart';

import 'package:xdu_treehole_web/core/navigation/post_link.dart';

Future<void> copyPostShareLink(String postId) {
  return Clipboard.setData(ClipboardData(text: postShareLink(postId)));
}
