import 'package:flutter/foundation.dart';

class AppConfig {
  // 运行时可通过 --dart-define=API_BASE_URL=http://host:port/api 覆盖
  // 移动端优先使用 MOBILE_API_BASE_URL（通过 MobileConfig 传入）
  static String get apiBaseUrl {
    // 先尝试移动端环境变量
    const mobileUrl = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
      defaultValue: '',
    );
    if (mobileUrl.isNotEmpty) {
      return mobileUrl;
    }
    // 移动端通过 --dart-define=MOBILE_API_BASE_URL=... 注入
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return const String.fromEnvironment(
        'MOBILE_API_BASE_URL',
        defaultValue: 'http://localhost:8080/api',
      );
    }
    if (kReleaseMode) {
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '/api',
      );
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080/api',
    );
  }

  // 生产构建时由 scripts/build_web_production.sh 通过 --dart-define=APP_VERSION=... 注入
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
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
