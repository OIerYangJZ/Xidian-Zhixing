import '../core/network/api_client.dart';
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

  Future<AiServerStatus> fetchStatus() async {
    final dynamic response = await _apiClient.get('/ai/models');
    final Map<String, dynamic> map = extractMap(response);
    final List<String> models = asList(map['models'])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    return AiServerStatus(
      model: readString(map, <String>['currentModel']) ?? '',
      models: models,
    );
  }
}

class AiServerStatus {
  const AiServerStatus({required this.model, required this.models});

  final String model;
  final List<String> models;

  bool get configured => model.trim().isNotEmpty;
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
