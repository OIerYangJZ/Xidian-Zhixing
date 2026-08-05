class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  /// True when the client gave up waiting. Distinct from a transport failure:
  /// the request may well have reached the server and still be running there.
  final bool isTimeout;

  @override
  String toString() {
    final int? code = statusCode;
    if (code == null) {
      return 'ApiException: $message';
    }
    return 'ApiException($code): $message';
  }
}
