import 'package:flutter/material.dart';

import '../../repositories/app_repositories.dart';
import '../../models/conversation_item.dart';
import '../../models/post_item.dart';
import '../../features/messages/chat_page.dart';
import '../../features/post/post_detail_page.dart';
import '../../features/profile/public_user_profile_page.dart';
import 'url_query_state.dart';

/// Where shared pages go for a post, a chat or a profile. The web pushes its
/// own pages; the Android app, which reuses pages such as 我的帖子 and the
/// public profile, points these at its router instead (see mobile_app_entry).
class AppNavigation {
  AppNavigation._();

  static Future<PostItem?> Function(BuildContext context, PostItem post)?
  openPost;
  static Future<void> Function(
    BuildContext context,
    ConversationItem conversation,
    String? peerUserId,
  )?
  openChat;
  static Future<void> Function(BuildContext context, String userId)? openUser;
}

Future<PostItem?> openPostDetailPage(
  BuildContext context, {
  required PostItem post,
}) async {
  final override = AppNavigation.openPost;
  if (override != null) return override(context, post);
  setPostIdOnUrl(post.id);
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(post: post),
      ),
    );
    try {
      return await AppRepositories.posts.fetchPostDetail(post.id);
    } catch (_) {
      return null;
    }
  } finally {
    setPostIdOnUrl(null);
  }
}

Future<void> openChatPage(
  BuildContext context, {
  required ConversationItem conversation,
  String? peerUserId,
}) {
  final override = AppNavigation.openChat;
  if (override != null) return override(context, conversation, peerUserId);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ChatPage(conversation: conversation, peerUserId: peerUserId),
    ),
  );
}

Future<void> openUserProfilePage(BuildContext context, String userId) {
  final override = AppNavigation.openUser;
  if (override != null) return override(context, userId);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PublicUserProfilePage(userId: userId),
    ),
  );
}
