import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
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
    final String localizedTitle = forbidden
        ? uiText(context, zh: '暂时无法访问', en: 'Access unavailable')
        : uiText(context, zh: '页面没有找到', en: 'Page not found');
    final String localizedMessage = forbidden
        ? uiText(
            context,
            zh: '当前账号没有访问这个页面的权限。',
            en: 'This account does not have permission to view this page.',
          )
        : uiText(
            context,
            zh: '链接可能已失效，或页面地址输入有误。',
            en: 'The link may have expired or the address may be incorrect.',
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          forbidden ? uiText(context, zh: '无权限', en: 'Forbidden') : '404',
        ),
      ),
      body: AppPageFrame(
        maxWidth: AppLayout.readingMaxWidth,
        alignment: Alignment.center,
        child: AppStatePanel(
          icon: forbidden
              ? Icons.lock_outline_rounded
              : Icons.explore_off_outlined,
          title: localizedTitle,
          message: localizedMessage,
          action: FilledButton.icon(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
            },
            icon: const Icon(Icons.home_outlined),
            label: Text(uiText(context, zh: '返回首页', en: 'Back to home')),
          ),
        ),
      ),
    );
  }
}
