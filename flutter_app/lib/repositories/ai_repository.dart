import 'package:flutter/widgets.dart';

import '../core/l10n/ui_text.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_utils.dart';

class AiRepository {
  AiRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AiChatResponse> sendMessage({
    required String content,
    required List<AiMessage> messages,
  }) async {
    final dynamic response = await _apiClient.post(
      '/ai/chat',
      body: <String, dynamic>{
        'content': content,
        'messages': messages
            .map(
              (AiMessage item) => <String, String>{
                'role': item.role,
                'content': item.content,
              },
            )
            .toList(),
      },
    );
    return AiChatResponse.fromJson(extractMap(response));
  }

  /// Never throws: every failure is classified into an [AiStatusProblem] so the
  /// UI can tell "the server has no AI configured" apart from "your session
  /// expired" or "the upstream provider rejected us".
  Future<AiServerStatus> fetchStatus() async {
    try {
      final dynamic response = await _apiClient.get('/ai/models');
      final Map<String, dynamic> map = extractMap(response);
      final List<String> models = asList(map['models'])
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      final String model = readString(map, <String>['currentModel']) ?? '';
      if (model.isEmpty) {
        return const AiServerStatus(
          model: '',
          models: <String>[],
          problem: AiStatusProblem.emptyModel,
        );
      }
      return AiServerStatus(model: model, models: models);
    } on ApiException catch (error) {
      return AiServerStatus.fromApiException(error);
    } catch (error) {
      return AiServerStatus(
        model: '',
        models: const <String>[],
        problem: AiStatusProblem.unknown,
        detail: error.toString(),
      );
    }
  }
}

/// Why the AI assistant is unavailable. The server returns a distinct HTTP
/// status for each case; collapsing them all into "not configured" hides the
/// difference between a deployment problem and a login problem.
enum AiStatusProblem {
  none,
  unauthorized,
  notConfigured,
  providerError,
  network,
  emptyModel,
  unknown,
}

class AiServerStatus {
  const AiServerStatus({
    required this.model,
    required this.models,
    this.problem = AiStatusProblem.none,
    this.detail = '',
    this.statusCode,
  });

  factory AiServerStatus.fromApiException(ApiException error) {
    final int? code = error.statusCode;
    final AiStatusProblem problem;
    if (code == null) {
      problem = AiStatusProblem.network;
    } else if (code == 401 || code == 403) {
      problem = AiStatusProblem.unauthorized;
    } else if (code == 503) {
      problem = AiStatusProblem.notConfigured;
    } else if (code == 502 || code == 504) {
      problem = AiStatusProblem.providerError;
    } else {
      problem = AiStatusProblem.unknown;
    }
    return AiServerStatus(
      model: '',
      models: const <String>[],
      problem: problem,
      detail: error.message,
      statusCode: code,
    );
  }

  final String model;
  final List<String> models;
  final AiStatusProblem problem;

  /// Raw server message, shown verbatim so it can be pasted into a bug report.
  final String detail;
  final int? statusCode;

  bool get configured =>
      problem == AiStatusProblem.none && model.trim().isNotEmpty;

  String problemTitleFor(Locale locale) {
    switch (problem) {
      case AiStatusProblem.none:
        return uiTextFor(locale, zh: '服务可用', en: 'Service available');
      case AiStatusProblem.unauthorized:
        return uiTextFor(locale, zh: '登录状态已失效', en: 'Session expired');
      case AiStatusProblem.notConfigured:
        return uiTextFor(locale, zh: '服务器尚未配置 AI', en: 'AI not configured');
      case AiStatusProblem.providerError:
        return uiTextFor(locale, zh: '模型接口调用失败', en: 'Provider call failed');
      case AiStatusProblem.network:
        return uiTextFor(locale, zh: '无法连接服务器', en: 'Cannot reach server');
      case AiStatusProblem.emptyModel:
        return uiTextFor(locale, zh: '服务器未返回模型名', en: 'No model returned');
      case AiStatusProblem.unknown:
        return uiTextFor(locale, zh: 'AI 服务不可用', en: 'AI unavailable');
    }
  }

  /// Actionable next step, deliberately naming the environment variables and
  /// the person who can fix it.
  String problemMessageFor(Locale locale) {
    switch (problem) {
      case AiStatusProblem.none:
        return uiTextFor(
          locale,
          zh: '当前模型：$model',
          en: 'Current model: $model',
        );
      case AiStatusProblem.unauthorized:
        return uiTextFor(
          locale,
          zh: '请重新登录后再使用 AI 助手。这与服务器 AI 配置无关。',
          en:
              'Sign in again to use the assistant. This is unrelated to the '
              'server AI configuration.',
        );
      case AiStatusProblem.notConfigured:
        return uiTextFor(
          locale,
          zh:
              '管理员需要在服务器 backend.env 中同时设置 BACKEND_AI_BASE_URL、'
              'BACKEND_AI_API_KEY 与 BACKEND_AI_MODEL，然后重建后端容器。只设置 API Key 不生效。',
          en:
              'An administrator must set BACKEND_AI_BASE_URL, BACKEND_AI_API_KEY '
              'and BACKEND_AI_MODEL together in backend.env, then recreate the '
              'backend container. Setting the API key alone has no effect.',
        );
      case AiStatusProblem.providerError:
        return uiTextFor(
          locale,
          zh: '服务器已配置 AI，但调用上游模型接口失败。请管理员检查地址、密钥、余额与网络出口。',
          en:
              'AI is configured, but the upstream provider call failed. An '
              'administrator should check the base URL, key, quota and egress.',
        );
      case AiStatusProblem.network:
        return uiTextFor(
          locale,
          zh: '请检查网络连接后重试。',
          en: 'Check your network connection and try again.',
        );
      case AiStatusProblem.emptyModel:
        return uiTextFor(
          locale,
          zh: '接口返回成功但没有 currentModel 字段，请管理员检查 BACKEND_AI_MODEL。',
          en:
              'The endpoint succeeded but returned no currentModel. An '
              'administrator should check BACKEND_AI_MODEL.',
        );
      case AiStatusProblem.unknown:
        return uiTextFor(
          locale,
          zh: '请稍后重试，若持续出现请联系管理员。',
          en: 'Try again later, and contact an administrator if it persists.',
        );
    }
  }

  /// `HTTP 503 · 服务器尚未配置 AI 服务` — the line worth pasting into a report.
  String get diagnosticLine {
    final List<String> parts = <String>[
      if (statusCode != null) 'HTTP $statusCode',
      if (detail.trim().isNotEmpty) detail.trim(),
    ];
    return parts.join(' · ');
  }
}

class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.references = const <AiReference>[],
  });

  final String role;
  final String content;
  final List<AiReference> references;
}

class AiReference {
  const AiReference({required this.type, required this.title});

  final String type;
  final String title;

  factory AiReference.fromJson(Map<String, dynamic> json) {
    return AiReference(
      type:
          readString(json, <String>['type', 'targetType', 'sourceType']) ?? '',
      title: readString(json, <String>['title']) ?? '',
    );
  }
}

class AiChatResponse {
  const AiChatResponse({required this.answer, required this.references});

  final String answer;
  final List<AiReference> references;

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      answer: readString(json, <String>['answer', 'reply', 'content']) ?? '',
      references: asList(json['references'] ?? json['citations'])
          .map((dynamic item) => AiReference.fromJson(asMap(item)))
          .where((AiReference item) => item.title.isNotEmpty)
          .toList(),
    );
  }
}
