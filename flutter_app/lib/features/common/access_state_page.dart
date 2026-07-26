import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';

class AccessStatePage extends StatelessWidget {
  const AccessStatePage.notFound({super.key})
    : forbidden = false,
      title = '页面没有找到',
      message = '链接可能已失效，或页面地址输入有误。';

  const AccessStatePage.forbidden({super.key})
    : forbidden = true,
      title = '暂时无法访问',
      message = '当前账号没有访问这个页面的权限。';

  final bool forbidden;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: AppPageFrame(
        maxWidth: AppLayout.readingMaxWidth,
        alignment: Alignment.center,
        child: AppStatePanel(
          icon: forbidden
              ? Icons.lock_outline_rounded
              : Icons.explore_off_outlined,
          title: title,
          message: message,
          action: FilledButton.icon(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('返回首页'),
          ),
        ),
      ),
    );
  }
}
