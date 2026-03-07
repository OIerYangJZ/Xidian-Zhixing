import 'package:flutter/material.dart';

import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'features/admin/admin_portal_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'widgets/home_shell.dart';

class XduTreeholeApp extends StatelessWidget {
  const XduTreeholeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '西电树洞',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthStore.instance.isAuthenticated
          ? const HomeShell()
          : (AdminAuthStore.instance.isAuthenticated
              ? const AdminPortalPage()
              : const LoginPage()),
    );
  }
}
