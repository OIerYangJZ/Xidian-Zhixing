import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:go_router/go_router.dart';

import '../core/navigation/post_detail_nav.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';
import 'core/config/mobile_config.dart';
import 'core/navigation/app_router.dart';
import 'core/state/app_settings_store.dart';
import 'core/state/mobile_providers.dart';
import 'core/theme/mobile_theme.dart';
import 'features/update/app_update_bootstrap.dart';

/// Pages shared with the web open posts, chats and profiles on the
/// Android router rather than pushing the web versions.
void useMobileNavigation() {
  AppNavigation.openPost = (BuildContext context, PostItem post) async {
    await context.push('/post/${Uri.encodeComponent(post.id)}');
    try {
      return await AppRepositories.posts.fetchPostDetail(post.id);
    } catch (_) {
      return null;
    }
  };
  AppNavigation.openChat = (context, conversation, peerUserId) => context.push(
    Uri(
      path: '/chat/${Uri.encodeComponent(conversation.id)}',
      queryParameters: <String, String>{
        'name': conversation.name,
        if (conversation.avatarUrl.isNotEmpty) 'avatar': conversation.avatarUrl,
        if ((peerUserId ?? conversation.peerUserId).isNotEmpty)
          'userId': peerUserId ?? conversation.peerUserId,
      },
    ).toString(),
  );
  AppNavigation.openUser = (context, userId) =>
      context.push('/user/${Uri.encodeComponent(userId)}');
}

Future<void> prepareMobileApp() async {
  useMobileNavigation();
  await AppSettingsStore.instance.init();
  if (MobileConfig.debugMode) {
    debugPrint('[mobile] API base: ${MobileConfig.apiBaseUrl}');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class XduTreeholeMobileApp extends ConsumerWidget {
  const XduTreeholeMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: '西电知行',
      debugShowCheckedModeBanner: false,
      theme: MobileTheme.getThemeData(
        settings.themeKey,
        settings.locale ?? const Locale('zh', 'CN'),
      ),
      darkTheme: MobileTheme.getThemeData(
        settings.themeKey,
        settings.locale ?? const Locale('zh', 'CN'),
        brightness: Brightness.dark,
      ),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppUpdateBootstrap(child: child ?? const SizedBox.shrink()),
    );
  }
}
