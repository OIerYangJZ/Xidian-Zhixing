import 'package:flutter/foundation.dart';

abstract final class AppBrand {
  static const String webDisplayName = '西电知行';
  static const String mobileDisplayName = '西电知行';

  static String get displayName => kIsWeb ? webDisplayName : mobileDisplayName;
}
