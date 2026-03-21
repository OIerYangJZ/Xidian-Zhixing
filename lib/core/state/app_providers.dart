import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/app_repositories.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((Ref ref) {
  return AppRepositories.posts;
});

final messageRepositoryProvider = Provider<MessageRepository>((Ref ref) {
  return AppRepositories.messages;
});

final notificationRepositoryProvider = Provider<NotificationRepository>((
  Ref ref,
) {
  return AppRepositories.notifications;
});
