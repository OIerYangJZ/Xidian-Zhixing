import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/repositories/ai_repository.dart';

void main() {
  const Locale zh = Locale('zh', 'CN');
  const Locale en = Locale('en');

  group('AiServerStatus classifies failures', () {
    test('503 means the server has no AI provider configured', () {
      final AiServerStatus status = AiServerStatus.fromApiException(
        ApiException(message: '服务器尚未配置 AI 服务', statusCode: 503),
      );

      expect(status.configured, isFalse);
      expect(status.problem, AiStatusProblem.notConfigured);
      expect(status.diagnosticLine, contains('HTTP 503'));
      expect(status.problemMessageFor(zh), isNot(contains('BACKEND_')));
      expect(status.problemMessageFor(en), isNot(contains('API_KEY')));
    });

    test('401 is a login problem, not a configuration problem', () {
      final AiServerStatus status = AiServerStatus.fromApiException(
        ApiException(message: 'Unauthorized', statusCode: 401),
      );

      expect(status.problem, AiStatusProblem.unauthorized);
      expect(status.problemTitleFor(en), isNot(contains('configured')));
    });

    test('502 means configured but the upstream provider failed', () {
      final AiServerStatus status = AiServerStatus.fromApiException(
        ApiException(message: '模型接口返回 401: bad key', statusCode: 502),
      );

      expect(status.problem, AiStatusProblem.providerError);
      expect(status.diagnosticLine, contains('模型接口返回 401'));
    });

    test('a missing status code is treated as a network failure', () {
      final AiServerStatus status = AiServerStatus.fromApiException(
        ApiException(message: 'XMLHttpRequest error'),
      );

      expect(status.problem, AiStatusProblem.network);
      expect(status.diagnosticLine, isNot(contains('HTTP')));
    });

    test('a client timeout blames the server hop, not the user network', () {
      final AiServerStatus status = AiServerStatus.fromApiException(
        ApiException(message: '请求超时，请稍后重试', isTimeout: true),
      );

      expect(status.problem, AiStatusProblem.timeout);
      expect(status.problemMessageFor(zh), isNot(contains('BACKEND_')));
      expect(status.problemMessageFor(zh), isNot(contains('检查网络连接')));
    });

    test('the initial placeholder never claims the service is available', () {
      const AiServerStatus status = AiServerStatus(
        model: '',
        models: <String>[],
        problem: AiStatusProblem.loading,
      );

      expect(status.isLoading, isTrue);
      expect(status.configured, isFalse);
      expect(status.problemTitleFor(zh), isNot(contains('服务可用')));
    });

    test(
      'a healthy response is configured without exposing provider details',
      () {
        const AiServerStatus status = AiServerStatus(
          model: 'gpt-4o-mini',
          models: <String>['gpt-4o-mini'],
        );

        expect(status.configured, isTrue);
        expect(status.problemMessageFor(zh), isNot(contains('gpt-4o-mini')));
      },
    );

    test('every problem has a non-empty user-facing explanation', () {
      for (final AiStatusProblem problem in AiStatusProblem.values) {
        final AiServerStatus status = AiServerStatus(
          model: problem == AiStatusProblem.none ? 'm' : '',
          models: const <String>[],
          problem: problem,
        );
        expect(status.problemTitleFor(zh), isNotEmpty);
        expect(status.problemMessageFor(en), isNotEmpty);
      }
    });
  });
}
