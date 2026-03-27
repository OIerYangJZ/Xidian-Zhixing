import 'package:flutter/foundation.dart';

/// 移动端专用配置文件
/// 通过 --dart-define 在编译时注入实际 API 地址
class MobileConfig {
  /// API 基础地址
  /// 通过 --dart-define=MOBILE_API_BASE_URL=... 在构建时注入
  /// 开发环境默认 localhost，生产环境必须通过 --dart-define 注入实际地址
  static const String apiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// App 版本号
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// 请求超时时间
  static const Duration requestTimeout = Duration(seconds: 15);

  /// 是否启用调试模式
  static const bool debugMode = kDebugMode;

  /// 检查是否为生产环境
  static bool get isProduction => !kDebugMode;
}
