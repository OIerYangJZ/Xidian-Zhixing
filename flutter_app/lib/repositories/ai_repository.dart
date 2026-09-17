import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_utils.dart';
import '../core/l10n/ui_text.dart';

class AiRepository {
  AiRepository(this._apiClient);

  final ApiClient _apiClient;

  static const Duration _chatTimeout = Duration(seconds: 165);

  Future<AiChatResponse> sendMessage({
    required String content,
    required List<AiMessage> messages,
  }) async {
    final dynamic response = await _apiClient.post(
      '/ai/chat',
      timeout: _chatTimeout,
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

  // Kept for non-UI compatibility with older integrations. The public app
  // never exposes provider or model settings.
  Future<AiServerStatus> fetchStatus() async {
    try {
      final dynamic response = await _apiClient.get(
        '/ai/models',
        timeout: const Duration(seconds: 30),
      );
      final Map<String, dynamic> map = extractMap(response);
      final List<String> models = asList(map['models'])
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      final String model = readString(map, <String>['currentModel']) ?? '';
      return model.isEmpty
          ? const AiServerStatus(
              model: '',
              models: <String>[],
              problem: AiStatusProblem.emptyModel,
            )
          : AiServerStatus(model: model, models: models);
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

enum AiStatusProblem {
  none,
  loading,
  unauthorized,
  notConfigured,
  providerError,
  timeout,
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
    if (error.isTimeout) {
      problem = AiStatusProblem.timeout;
    } else if (code == null) {
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
  final String detail;
  final int? statusCode;

  bool get configured =>
      problem == AiStatusProblem.none && model.trim().isNotEmpty;

  bool get isLoading => problem == AiStatusProblem.loading;

  String problemTitleFor(Locale locale) {
    switch (problem) {
      case AiStatusProblem.none:
        return uiTextFor(locale, zh: '服务可用', en: 'Service available');
      case AiStatusProblem.loading:
        return uiTextFor(locale, zh: '正在准备', en: 'Preparing');
      case AiStatusProblem.unauthorized:
        return uiTextFor(locale, zh: '登录状态已失效', en: 'Session expired');
      case AiStatusProblem.notConfigured:
      case AiStatusProblem.providerError:
      case AiStatusProblem.timeout:
      case AiStatusProblem.network:
      case AiStatusProblem.emptyModel:
      case AiStatusProblem.unknown:
        return uiTextFor(locale, zh: '暂时无法使用', en: 'Temporarily unavailable');
    }
  }

  String problemMessageFor(Locale locale) {
    switch (problem) {
      case AiStatusProblem.none:
        return uiTextFor(locale, zh: '服务已准备好。', en: 'The service is ready.');
      case AiStatusProblem.loading:
        return uiTextFor(
          locale,
          zh: '正在准备，请稍候。',
          en: 'Preparing, please wait.',
        );
      case AiStatusProblem.unauthorized:
        return uiTextFor(
          locale,
          zh: '请重新登录后重试。',
          en: 'Sign in again and retry.',
        );
      case AiStatusProblem.notConfigured:
      case AiStatusProblem.providerError:
      case AiStatusProblem.timeout:
      case AiStatusProblem.network:
      case AiStatusProblem.emptyModel:
      case AiStatusProblem.unknown:
        return uiTextFor(locale, zh: '请稍后重试。', en: 'Please try again later.');
    }
  }

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
  const AiReference({
    required this.type,
    required this.title,
    this.targetId = '',
    this.jumpUrl = '',
    this.sourceUrl = '',
  });

  final String type;
  final String title;
  final String targetId;
  final String jumpUrl;
  final String sourceUrl;

  factory AiReference.fromJson(Map<String, dynamic> json) {
    return AiReference(
      type:
          readString(json, <String>['type', 'targetType', 'sourceType']) ?? '',
      title: readString(json, <String>['title']) ?? '',
      targetId: readString(json, <String>['targetId', 'id']) ?? '',
      jumpUrl: readString(json, <String>['jumpUrl', 'path']) ?? '',
      sourceUrl: readString(json, <String>['sourceUrl', 'url']) ?? '',
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
