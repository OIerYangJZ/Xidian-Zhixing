import 'package:flutter/material.dart';

import '../../models/post_item.dart';
import '../../features/post/post_detail_page.dart';
import 'url_query_state.dart';

Future<void> openPostDetailPage(
  BuildContext context, {
  required PostItem post,
}) async {
  setPostIdOnUrl(post.id);
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(post: post),
      ),
    );
  } finally {
    setPostIdOnUrl(null);
  }
}
