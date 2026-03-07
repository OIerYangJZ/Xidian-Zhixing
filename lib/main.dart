import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'core/emoji/emoji_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdminAuthStore.instance.init();
  await AuthStore.instance.init();
  await EmojiSettingsStore.instance.init();
  runApp(const ProviderScope(child: XduTreeholeApp()));
}
