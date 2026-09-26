import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_store.dart';

import '../../repositories/app_repositories.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/ai_repository.dart';
import '../../repositories/appeal_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/campus_repository.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/post_repository.dart';
import '../../repositories/user_repository.dart';

/// Changes whenever the signed-in account (or its ban) changes. Providers
/// holding one account's data watch this, so the next account never sees
/// the previous one's feed, chats or notifications.
final accountEpochProvider = Provider<int>((Ref ref) {
  final ValueNotifier<int> epoch = AuthStore.instance.accountEpoch;
  void onChange() => ref.invalidateSelf();
  epoch.addListener(onChange);
  ref.onDispose(() => epoch.removeListener(onChange));
  return epoch.value;
});

final postRepositoryProvider = Provider<PostRepository>((Ref ref) {
  return AppRepositories.posts;
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AppRepositories.auth;
});

final userRepositoryProvider = Provider<UserRepository>((Ref ref) {
  return AppRepositories.users;
});

final messageRepositoryProvider = Provider<MessageRepository>((Ref ref) {
  return AppRepositories.messages;
});

final notificationRepositoryProvider = Provider<NotificationRepository>((
  Ref ref,
) {
  return AppRepositories.notifications;
});

final campusRepositoryProvider = Provider<CampusRepository>((Ref ref) {
  return AppRepositories.campus;
});

final aiRepositoryProvider = Provider<AiRepository>((Ref ref) {
  return AppRepositories.ai;
});

final appealRepositoryProvider = Provider<AppealRepository>((Ref ref) {
  return AppRepositories.appeals;
});

final adminRepositoryProvider = Provider<AdminRepository>((Ref ref) {
  return AppRepositories.adminPortal;
});
