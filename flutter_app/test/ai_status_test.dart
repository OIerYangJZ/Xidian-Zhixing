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
      expect(status.problemMessageFor(zh), contains('BACKEND_AI_BASE_URL'));
      expect(status.problemMessageFor(en), contains('BACKEND_AI_API_KEY'));
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
        ApiException(message: '请求超时，请稍后重试'),
      );

      expect(status.problem, AiStatusProblem.network);
      expect(status.diagnosticLine, isNot(contains('HTTP')));
    });

    test('a healthy response is configured and reports the model', () {
      const AiServerStatus status = AiServerStatus(
        model: 'gpt-4o-mini',
        models: <String>['gpt-4o-mini'],
      );

      expect(status.configured, isTrue);
      expect(status.problemMessageFor(zh), contains('gpt-4o-mini'));
    });

    test('every problem has a distinct, non-empty explanation', () {
      final Set<String> titles = <String>{};
      for (final AiStatusProblem problem in AiStatusProblem.values) {
        final AiServerStatus status = AiServerStatus(
          model: problem == AiStatusProblem.none ? 'm' : '',
          models: const <String>[],
          problem: problem,
        );
        expect(status.problemTitleFor(zh), isNotEmpty);
        expect(status.problemMessageFor(en), isNotEmpty);
        titles.add(status.problemTitleFor(en));
      }
      expect(titles.length, AiStatusProblem.values.length);
    });
  });
}
