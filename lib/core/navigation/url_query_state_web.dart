// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

String? currentPostIdFromUrl() {
  final Uri uri = Uri.parse(html.window.location.href);
  final String value = (uri.queryParameters['postId'] ?? '').trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}

void setPostIdOnUrl(String? postId) {
  final Uri uri = Uri.parse(html.window.location.href);
  final Map<String, String> qp = Map<String, String>.from(uri.queryParameters);
  final String value = (postId ?? '').trim();
  if (value.isEmpty) {
    qp.remove('postId');
  } else {
    qp['postId'] = value;
  }
  final Uri next = uri.replace(queryParameters: qp.isEmpty ? null : qp);
  html.window.history.replaceState(null, '', next.toString());
}
