import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xdu_treehole_web/features/messages/messages_controller.dart'
    show messagesControllerProvider;
import 'package:xdu_treehole_web/features/notifications/notifications_controller.dart'
    show notificationsControllerProvider;

/// Re-export all shared providers for lib/mobile/features/ pages
export 'package:xdu_treehole_web/core/state/app_providers.dart';
export 'package:xdu_treehole_web/features/feed/feed_controller.dart'
    show feedControllerProvider;
export 'package:xdu_treehole_web/features/search/search_controller.dart';
export 'package:xdu_treehole_web/features/messages/messages_controller.dart'
    show messagesControllerProvider;
export 'package:xdu_treehole_web/features/notifications/notifications_controller.dart'
    show notificationsControllerProvider;

/// Mobile-only Providers

/// 当前 Tab 索引
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

/// 骨架屏加载状态
final skeletonLoadingProvider = StateProvider<bool>((ref) => false);

/// 通知未读数
final notificationUnreadCountProvider = Provider<int>((ref) {
  final notificationsState = ref.watch(notificationsControllerProvider);
  return notificationsState.unreadCount;
});

/// 消息未读数
final messageUnreadCountProvider = Provider<int>((ref) {
  final messagesState = ref.watch(messagesControllerProvider);
  return messagesState.conversations.fold<int>(
    0,
    (int sum, item) => sum + item.unreadCount,
  );
});

/// 搜索历史
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  void add(String keyword) {
    if (keyword.trim().isEmpty) return;
    final trimmed = keyword.trim();
    state = [trimmed, ...state.where((item) => item != trimmed).take(9)].toList();
  }

  void remove(String keyword) {
    state = state.where((item) => item != keyword).toList();
  }

  void clear() {
    state = [];
  }
}
