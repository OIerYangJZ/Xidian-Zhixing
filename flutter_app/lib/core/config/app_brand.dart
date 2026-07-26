import 'package:flutter/foundation.dart';

abstract final class AppBrand {
  static const String webDisplayName = '西电知行';
  static const String mobileDisplayName = '西电知行';
  static const String logoAsset = 'web/icons/Icon-192.png';

  static String get displayName => kIsWeb ? webDisplayName : mobileDisplayName;
}
