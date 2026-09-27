import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/app_repositories.dart';
import '../auth/login_page.dart';
import 'admin_console_page.dart';
import 'admin_login_page.dart';

class AdminPortalPage extends StatelessWidget {
  const AdminPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // 书院·青绿 marks the admin side apart from the student site.
      data: AppTheme.designSystemFor(
        themeKey: 'zhuqing',
        brightness: Theme.of(context).brightness,
      ),
      child: AdminConsolePage(
        repository: AppRepositories.adminPortal,
        onLogout: () async {
          await AppRepositories.adminAuth.logout();
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => AppConfig.adminOnly
                  ? const AdminLoginPage()
                  : const LoginPage(),
            ),
            (Route<dynamic> route) => false,
          );
        },
      ),
    );
  }
}
