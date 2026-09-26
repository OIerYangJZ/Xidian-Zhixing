import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';

http.Client _answering(int status, Map<String, Object> body) =>
    MockClient((http.Request request) async => http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    ));

const Map<String, Object> _banned = <String, Object>{
  'message': '账号已被封禁，仅可提交解封申诉',
  'data': <String, Object>{'accountState': 'banned'},
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthStore.instance.init();
    await AuthStore.instance.saveToken('session-token');
    AuthStore.instance.setBanned(false);
  });

  tearDown(() => AuthStore.instance.clear());

  Future<void> call(ApiClient client) async {
    await expectLater(client.get('/posts'), throwsA(isA<ApiException>()));
  }

  test('a 401 ends the session and leaves a notice for the login page', () async {
    final Future<SessionChange> change = AuthStore.instance.sessionChanges.first;
    await call(ApiClient(httpClient: _answering(401, <String, Object>{'message': '请先登录'})));
    expect(await change, SessionChange.expired);
    expect(AuthStore.instance.isAuthenticated, isFalse);
    expect(AuthStore.instance.takeSessionExpiredNotice(), isTrue);
    expect(AuthStore.instance.takeSessionExpiredNotice(), isFalse);
  });

  test('a banned 403 marks the account banned, once', () async {
    final List<SessionChange> changes = <SessionChange>[];
    final sub = AuthStore.instance.sessionChanges.listen(changes.add);
    addTearDown(sub.cancel);
    final ApiClient client = ApiClient(httpClient: _answering(403, _banned));
    await call(client);
    await call(client);
    await Future<void>.delayed(Duration.zero);
    expect(AuthStore.instance.isBanned, isTrue);
    expect(AuthStore.instance.isAuthenticated, isTrue);
    expect(changes, <SessionChange>[SessionChange.banned]);
  });

  test('other 403s leave the session alone', () async {
    await call(ApiClient(
      httpClient: _answering(403, <String, Object>{'message': '对方已关闭私信'}),
    ));
    expect(AuthStore.instance.isBanned, isFalse);
    expect(AuthStore.instance.isAuthenticated, isTrue);
  });

  test('the admin client never touches the student session', () async {
    await call(ApiClient(
      httpClient: _answering(401, <String, Object>{'message': '请先登录'}),
      tokenResolver: () => 'admin-token',
    ));
    expect(AuthStore.instance.isAuthenticated, isTrue);
  });

  test('a 401 to a request from an older session is ignored', () async {
    final ApiClient client = ApiClient(
      httpClient: MockClient((http.Request request) async {
        // Signed in again while this request was in flight.
        await AuthStore.instance.saveToken('new-token');
        return http.Response('{"message":"请先登录"}', 401);
      }),
    );
    await call(client);
    expect(AuthStore.instance.token, 'new-token');
  });
}
