import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/mobile/features/update/app_update_controller.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import 'package:xdu_treehole_web/repositories/message_repository.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/repositories/user_repository.dart';
import 'package:xdu_treehole_web/models/section_item.dart';

void main() {
  test('in-app APK update is available only on Android', () {
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppUpdateController.instance.supportsInAppUpdate, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppUpdateController.instance.supportsInAppUpdate, isTrue);
  });

  test(
    'list repositories propagate server failures instead of fake empty data',
    () async {
      final MockClient failingClient = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{'message': 'server unavailable'}),
          500,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      );
      final ApiClient apiClient = ApiClient(httpClient: failingClient);

      await expectLater(
        MessageRepository(apiClient).fetchConversations(),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        PostRepository(apiClient).fetchPosts(),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        UserRepository(apiClient).fetchFollowing(),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('create post rejects a success response without post data', () async {
    final MockClient emptySuccessClient = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    final PostRepository repository = PostRepository(
      ApiClient(httpClient: emptySuccessClient),
    );
    final CreatePostInput input = CreatePostInput(
      title: '测试',
      content: '正文',
      section: const SectionItem(
        id: 'section-general',
        sectionType: 'general',
        sectionId: 'general',
        sectionName: '综合',
      ),
      tags: const <String>[],
      allowComment: true,
      allowDm: false,
      privateOnly: false,
      status: PostStatus.ongoing,
      hasImage: false,
    );

    await expectLater(
      repository.createPost(input),
      throwsA(isA<FormatException>()),
    );
  });

  test('logout propagates server failure', () async {
    final MockClient failingClient = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(<String, dynamic>{'message': 'logout failed'}),
        503,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );

    await expectLater(
      AuthRepository(ApiClient(httpClient: failingClient)).logout(),
      throwsA(isA<Exception>()),
    );
  });

  test('background upload rejects an unapproved moderation result', () async {
    final MockClient pendingClient = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'url': '/api/storage/background.png',
            'status': 'pending',
            'moderationReason': '等待人工审核',
          },
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );

    await expectLater(
      UserRepository(
        ApiClient(httpClient: pendingClient),
      ).uploadBackgroundImage(
        fileName: 'background.png',
        contentType: 'image/png',
        dataBase64: 'aW1hZ2U=',
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          '等待人工审核',
        ),
      ),
    );
  });

  test(
    'list repositories reject malformed records instead of dropping them',
    () async {
      final MockClient malformedClient = MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'data': <Map<String, dynamic>>[<String, dynamic>{}],
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      );

      await expectLater(
        MessageRepository(
          ApiClient(httpClient: malformedClient),
        ).fetchConversations(),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
