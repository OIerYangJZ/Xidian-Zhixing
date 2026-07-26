import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PostDraft {
  const PostDraft({
    required this.title,
    required this.content,
    required this.anonymousAlias,
    required this.useAnonymousAlias,
    required this.useMarkdown,
    required this.privateOnly,
  });

  final String title;
  final String content;
  final String anonymousAlias;
  final bool useAnonymousAlias;
  final bool useMarkdown;
  final bool privateOnly;

  Map<String, Object> toJson() => <String, Object>{
    'title': title,
    'content': content,
    'anonymousAlias': anonymousAlias,
    'useAnonymousAlias': useAnonymousAlias,
    'useMarkdown': useMarkdown,
    'privateOnly': privateOnly,
  };

  factory PostDraft.fromJson(Map<String, dynamic> json) => PostDraft(
    title: (json['title'] ?? '').toString(),
    content: (json['content'] ?? '').toString(),
    anonymousAlias: (json['anonymousAlias'] ?? '').toString(),
    useAnonymousAlias: json['useAnonymousAlias'] == true,
    useMarkdown: json['useMarkdown'] == true,
    privateOnly: json['privateOnly'] == true,
  );
}

/// Persists the writer's text and publishing choices between composer sessions.
class PostDraftStore {
  PostDraftStore._();

  static const String _storageKeyPrefix = 'post_composer_draft_';

  static Future<PostDraft?> load({required String userId}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? encoded = preferences.getString(_storageKeyFor(userId));
    if (encoded == null || encoded.isEmpty) return null;
    return PostDraft.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  static Future<void> save({
    required String userId,
    required PostDraft draft,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKeyFor(userId),
      jsonEncode(draft.toJson()),
    );
  }

  static Future<void> clear({required String userId}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKeyFor(userId));
  }

  static String _storageKeyFor(String userId) {
    final String normalized = userId.trim();
    if (normalized.isEmpty) {
      throw StateError('Cannot access a draft without an authenticated user.');
    }
    return '$_storageKeyPrefix$normalized';
  }
}
