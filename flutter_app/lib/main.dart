import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/emoji/emoji_settings_store.dart';
import 'core/state/app_locale_store.dart';
import 'mobile/mobile_app_entry_stub.dart'
    if (dart.library.io) 'mobile/mobile_app_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait(<Future<void>>[
    AuthStore.instance.init(),
    AdminAuthStore.instance.init(),
    EmojiSettingsStore.instance.init(),
    AppLocaleStore.instance.init(),
  ]);

  if (kIsWeb) {
    runApp(const ProviderScope(child: XduTreeholeApp()));
    return;
  }

  await prepareMobileApp();
  runApp(const ProviderScope(child: XduTreeholeMobileApp()));
}
