class AppConfig {
  // 运行时可通过 --dart-define=API_BASE_URL=http://host:port/api 覆盖
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  // 当后端不可用时，列表型页面回退到本地 mock，避免前端无法演示。
  static const bool enableMockFallback = true;
}
