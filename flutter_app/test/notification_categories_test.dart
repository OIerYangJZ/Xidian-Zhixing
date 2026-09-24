import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/features/notifications/notifications_controller.dart';
import 'package:xdu_treehole_web/models/notification_item.dart';
import 'package:xdu_treehole_web/repositories/notification_repository.dart';

NotificationItem _item(String id, String type, {bool read = false}) =>
    NotificationItem.fromJson(<String, dynamic>{
      'id': id,
      'type': type,
      'relatedType': type == 'reply' ? 'comment' : 'post',
      'postId': 'p1',
      'isRead': read,
    });

class _FakeRepo extends NotificationRepository {
  _FakeRepo(this.items) : super(ApiClient());

  final List<NotificationItem> items;
  final List<String?> markedAll = <String?>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async => items;

  @override
  Future<void> markAllRead({String? category}) async => markedAll.add(category);
}

void main() {
  test('categories follow the server mapping', () {
    expect(_item('a', 'reply').category, 'reply');
    expect(_item('b', 'system_announcement').category, 'system');
    expect(_item('c', 'something_new').category, 'system');
  });

  test('replies open the post they were left on', () {
    expect(_item('a', 'reply').opensPost, isTrue);
    expect(_item('b', 'report_result').opensPost, isTrue);
    expect(
      NotificationItem.fromJson(<String, dynamic>{
        'id': 'c',
        'type': 'report_result',
        'relatedType': 'report',
        'relatedId': 'r1',
      }).opensPost,
      isFalse,
    );
  });

  test('全部已读 on a filtered list marks only that category', () async {
    final _FakeRepo repo = _FakeRepo(<NotificationItem>[
      _item('n1', 'comment'),
      _item('n2', 'reply'),
      _item('n3', 'reply'),
      _item('n4', 'like', read: true),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final NotificationsController controller = container.read(
      notificationsControllerProvider.notifier,
    );
    await controller.loadInitial();

    NotificationsState state() => container.read(notificationsControllerProvider);
    expect(state().unreadIn(null), 3);
    expect(state().unreadIn('reply'), 2);
    expect(state().unreadIn('like'), 0);

    controller.selectCategory('reply');
    expect(state().visibleItems.map((NotificationItem i) => i.id), <String>[
      'n2',
      'n3',
    ]);

    await controller.markAllRead();
    expect(repo.markedAll, <String?>['reply']);
    expect(state().unreadIn('reply'), 0);
    expect(state().unreadIn('comment'), 1, reason: 'other categories untouched');

    controller.selectCategory(null);
    await controller.markAllRead();
    expect(repo.markedAll, <String?>['reply', null]);
    expect(state().unreadIn(null), 0);
  });
}
