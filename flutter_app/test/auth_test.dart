import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';

void main() {
  group('AuthRepository official unified authentication', () {
    test('creates a redirect session without collecting credentials', () async {
      late Map<String, dynamic> submitted;
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/xidian/session');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'attemptId': 'attempt-1',
              'status': 'pending',
              'platform': 'web',
              'authorizeUrl':
                  'https://zhixing.xidian.edu.cn/api/auth/xidian/start?attempt=attempt-1',
            },
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final AuthRepository repository = AuthRepository(
        ApiClient(httpClient: client),
      );

      final XidianAuthSessionResult result = await repository
          .createXidianAuthSession(platform: 'web', nextPath: '/');

      expect(submitted, <String, dynamic>{'platform': 'web', 'nextPath': '/'});
      expect(submitted.containsKey('studentId'), isFalse);
      expect(submitted.containsKey('password'), isFalse);
      expect(result.isPending, isTrue);
      expect(result.attemptId, 'attempt-1');
    });

    test('consumes a validated IDS ticket session', () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/auth/xidian/session/attempt-1');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'attemptId': 'attempt-1',
              'status': 'authenticated',
              'platform': 'web',
              'token': 'ids-session-token',
              'verified': true,
              'studentId': '2300000000',
              'email': '2300000000@stu.xidian.edu.cn',
            },
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final AuthRepository repository = AuthRepository(
        ApiClient(httpClient: client),
      );

      final XidianAuthSessionResult result = await repository
          .fetchXidianAuthSession('attempt-1');

      expect(result.isAuthenticated, isTrue);
      expect(result.token, 'ids-session-token');
      expect(result.studentId, '2300000000');
    });

    test('rejects authenticated status without a complete local session', () {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'attemptId': 'attempt-1',
              'status': 'authenticated',
              'platform': 'mobile',
              'verified': true,
              'studentId': '2300000000',
            },
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final AuthRepository repository = AuthRepository(
        ApiClient(httpClient: client),
      );

      expect(
        () => repository.fetchXidianAuthSession('attempt-1'),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            '统一认证结果缺少有效登录凭据',
          ),
        ),
      );
    });

    test('preserves an official authentication availability error', () {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'message': '学校统一身份认证暂时不可用'}),
          503,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final AuthRepository repository = AuthRepository(
        ApiClient(httpClient: client),
      );

      expect(
        () => repository.createXidianAuthSession(platform: 'web'),
        throwsA(
          isA<ApiException>().having(
            (ApiException error) => error.message,
            'message',
            '学校统一身份认证暂时不可用',
          ),
        ),
      );
    });
  });
}
