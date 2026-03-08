class AppConfig {
  // 运行时可通过 --dart-define=API_BASE_URL=http://host:port/api 覆盖
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  // 当后端不可用时，列表型页面回退到本地 mock，避免前端无法演示。
  static const bool enableMockFallback = true;

  static String resolveUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    if (trimmed.startsWith('//')) {
      return '${Uri.base.scheme}:$trimmed';
    }

    final Uri? apiUri = Uri.tryParse(apiBaseUrl);
    if (trimmed.startsWith('/')) {
      if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
        return apiUri.resolve(trimmed).toString();
      }
      return Uri.base.resolve(trimmed).toString();
    }

    if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
      return apiUri.resolve(trimmed).toString();
    }
    return Uri.base.resolve(trimmed).toString();
  }
}
