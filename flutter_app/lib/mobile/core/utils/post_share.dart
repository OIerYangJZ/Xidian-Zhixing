import 'package:flutter/services.dart';

/// There is no public URL for a single post yet, so sharing copies a line
/// that names the post rather than a link.
Future<void> copyPostShareText(String postId) {
  return Clipboard.setData(ClipboardData(text: '查看西电知行帖子：$postId'));
}
