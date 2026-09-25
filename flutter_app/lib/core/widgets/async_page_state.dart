import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import '../../design_system/design_system.dart';

class AsyncPageState extends StatelessWidget {
  const AsyncPageState({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
    this.onRetry,
    this.loadingLabel,
    this.emptyFallback,
  });

  final bool loading;
  final String? error;
  final Widget child;
  final VoidCallback? onRetry;
  final String? loadingLabel;
  final Widget? emptyFallback;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Semantics(
        liveRegion: true,
        label: loadingLabel ?? uiText(context, zh: '正在加载', en: 'Loading'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loadingLabel ??
                        uiText(context, zh: '正在加载内容', en: 'Loading content'),
                    style: ZxType.body.copyWith(
                      color: ZxTokens.of(context).text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (error != null && (emptyFallback != null)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ZxInlineMessage(
            message: error!,
            tone: ZxMessageTone.danger,
            actionLabel: onRetry == null
                ? null
                : uiText(context, zh: '重试', en: 'Retry'),
            onAction: onRetry,
          ),
          const SizedBox(height: 12),
          emptyFallback!,
        ],
      );
    }

    return Column(
      children: <Widget>[
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ZxInlineMessage(
              message: error!,
              tone: ZxMessageTone.danger,
              actionLabel: onRetry == null
                  ? null
                  : uiText(context, zh: '重试', en: 'Retry'),
              onAction: onRetry,
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
