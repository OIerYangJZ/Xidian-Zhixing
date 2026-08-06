import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, TargetPlatform, defaultTargetPlatform;

class AppConfig {
  static const String _localApiBaseUrl = 'http://127.0.0.1:8080/api';
  static const String _androidEmulatorApiBaseUrl = 'http://10.0.2.2:8080/api';
  // Web 通常使用 API_BASE_URL 覆盖；移动端使用 MOBILE_API_BASE_URL 覆盖。
  static String get apiBaseUrl {
    const mobileUrl = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
      defaultValue: '',
    );
    if (mobileUrl.trim().isNotEmpty) {
      return _normalizeApiBaseUrl(mobileUrl);
    }

    const webUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (kIsWeb) {
      if (webUrl.trim().isNotEmpty) {
        return _normalizeApiBaseUrl(webUrl);
      }
      return kReleaseMode ? '/api' : _localApiBaseUrl;
    }

    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      return _defaultMobileApiBaseUrl;
    }

    if (webUrl.trim().isNotEmpty) {
      return _normalizeApiBaseUrl(webUrl);
    }
    if (kReleaseMode) {
      throw StateError('生产构建缺少 API_BASE_URL；请在构建时显式注入 HTTPS API 地址');
    }
    return _localApiBaseUrl;
  }

  static String get _defaultMobileApiBaseUrl {
    if (kReleaseMode) {
      throw StateError('移动端生产构建缺少 MOBILE_API_BASE_URL；请在构建时显式注入 HTTPS API 地址');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 模拟器访问宿主机 localhost 需要使用 10.0.2.2。
      return _androidEmulatorApiBaseUrl;
    }
    // iOS 模拟器可以直接访问宿主机 127.0.0.1；真机调试请注入局域网 IP。
    return _localApiBaseUrl;
  }

  // 生产构建时由 scripts/build_web_production.sh 通过 --dart-define=APP_VERSION=... 注入
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  // 生产/现网不再展示本地 mock 卡片，空数据时直接显示真实空状态。
  static const bool enableMockFallback = false;

  static String resolveUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      // These values come from server data (media urls, announcement targets)
      // and are fed to image loaders, url_launcher and anchor hrefs.  Only
      // plain web schemes may pass; javascript:/data:/file:/intent: must not.
      if (!_isWebScheme(parsed.scheme)) {
        return '';
      }
      final String host = parsed.host.trim().toLowerCase();
      if (_isLoopbackHost(host)) {
        final String path = parsed.path.isEmpty ? '/' : parsed.path;
        if (trimmed.startsWith('/')) {
          return Uri.base.resolve(trimmed).toString();
        }
        final Uri? apiUri = Uri.tryParse(apiBaseUrl);
        if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
          return apiUri
              .resolveUri(
                Uri(
                  path: path,
                  query: parsed.hasQuery ? parsed.query : null,
                  fragment: parsed.hasFragment ? parsed.fragment : null,
                ),
              )
              .toString();
        }
        return Uri.base
            .resolveUri(
              Uri(
                path: path,
                query: parsed.hasQuery ? parsed.query : null,
                fragment: parsed.hasFragment ? parsed.fragment : null,
              ),
            )
            .toString();
      }
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

  static bool isWebUrl(String value) {
    final Uri? parsed = Uri.tryParse(value.trim());
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      return false;
    }
    return _isWebScheme(parsed.scheme) && parsed.host.trim().isNotEmpty;
  }

  static bool _isWebScheme(String scheme) {
    final String normalized = scheme.trim().toLowerCase();
    return normalized == 'http' || normalized == 'https';
  }

  static bool _isLoopbackHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  static String _normalizeApiBaseUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed == '/') {
      return trimmed;
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
