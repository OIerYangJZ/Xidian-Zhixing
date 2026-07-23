import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/app_repositories.dart';
import '../auth/login_page.dart';
import 'admin_console_page.dart';

class AdminPortalPage extends StatelessWidget {
  const AdminPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminTheme(Theme.of(context).brightness),
      child: AdminConsolePage(
        repository: AppRepositories.adminPortal,
        onLogout: () async {
          await AppRepositories.adminAuth.logout();
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        },
      ),
    );
  }
}
