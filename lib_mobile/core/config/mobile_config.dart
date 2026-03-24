import 'package:flutter/foundation.dart';

/// 移动端专用配置文件
/// 通过 --dart-define 在编译时注入实际 API 地址
class MobileConfig {
  /// API 基础地址
  /// 当前临时默认直连现网 HTTP，后续补域名和 HTTPS 后再切回正式地址。
  static const String apiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'http://81.69.16.134/api',
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
