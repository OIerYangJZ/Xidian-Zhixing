import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/notification_item.dart';
import '../../core/l10n/ui_text.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const <NotificationItem>[],
    this.loading = true,
    this.actionBusy = false,
    this.error,
    this.category,
  });

  final List<NotificationItem> items;
  final bool loading;
  final bool actionBusy;
  final String? error;

  /// Selected filter; null shows every category.
  final String? category;

  int get unreadCount =>
      items.where((NotificationItem item) => !item.isRead).length;

  List<NotificationItem> get visibleItems => category == null
      ? items
      : items.where((NotificationItem item) => item.category == category).toList();

  int unreadIn(String? category) => items
      .where((NotificationItem item) =>
          !item.isRead && (category == null || item.category == category))
      .length;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? loading,
    bool? actionBusy,
    String? error,
    bool clearError = false,
    String? category,
    bool clearCategory = false,
  }) {
    return NotificationsState(
      category: clearCategory ? null : (category ?? this.category),
      items: items ?? this.items,
      loading: loading ?? this.loading,
      actionBusy: actionBusy ?? this.actionBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref) : super(const NotificationsState());

  final Ref _ref;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    await _reload();
  }

  Future<void> refresh() => _reload(showLoading: false);

  Future<void> markRead(String notificationId) async {
    final NotificationItem? existing =
        state.items.cast<NotificationItem?>().firstWhere(
              (NotificationItem? item) => item?.id == notificationId,
              orElse: () => null,
            );
    if (existing == null || existing.isRead) {
      return;
    }
    final List<NotificationItem> optimistic = state.items
        .map(
          (NotificationItem item) => item.id == notificationId
              ? item.copyWith(
                  isRead: true, readAt: DateTime.now().toIso8601String())
              : item,
        )
        .toList();
    state = state.copyWith(items: optimistic, clearError: true);
    try {
      await _ref.read(notificationRepositoryProvider).markRead(notificationId);
    } catch (error) {
      state = state.copyWith(
        error: uiTextGlobal(
          zh: '通知已读失败：$error',
          en: 'Could not mark as read: $error',
        ),
      );
      await refresh();
    }
  }

  void selectCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  /// Marks the selected category read, or everything when none is selected.
  Future<void> markAllRead() async {
    final String? category = state.category;
    if (state.actionBusy || state.unreadIn(category) == 0) {
      return;
    }
    state = state.copyWith(actionBusy: true, clearError: true);
    final String now = DateTime.now().toIso8601String();
    final List<NotificationItem> optimistic = state.items
        .map((NotificationItem item) =>
            item.isRead || (category != null && item.category != category)
                ? item
                : item.copyWith(isRead: true, readAt: now))
        .toList();
    state =
        state.copyWith(items: optimistic, actionBusy: true, clearError: true);
    try {
      await _ref
          .read(notificationRepositoryProvider)
          .markAllRead(category: category);
      state = state.copyWith(actionBusy: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        actionBusy: false,
        error: uiTextGlobal(
          zh: '全部已读失败：$error',
          en: 'Could not mark all as read: $error',
        ),
      );
      await refresh();
    }
  }

  Future<void> _reload({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final List<NotificationItem> items =
          await _ref.read(notificationRepositoryProvider).fetchNotifications();
      state = state.copyWith(
        items: items,
        loading: false,
        actionBusy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        actionBusy: false,
        error: uiTextGlobal(
          zh: '通知加载失败：$error',
          en: 'Could not load notifications: $error',
        ),
      );
    }
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>(
  (Ref ref) => NotificationsController(ref),
);
