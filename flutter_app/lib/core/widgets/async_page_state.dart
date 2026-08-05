import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import '../theme/design_tokens.dart';
import 'app_surfaces.dart';

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
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    loadingLabel ??
                        uiText(context, zh: '正在加载内容', en: 'Loading content'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          AppInlineMessage(
            title: uiText(
              context,
              zh: '内容加载失败',
              en: 'Failed to load content',
            ),
            message: error!,
            tone: AppMessageTone.error,
            action: onRetry == null
                ? null
                : TextButton(
                    onPressed: onRetry,
                    child: Text(uiText(context, zh: '重试', en: 'Retry')),
                  ),
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
            child: AppInlineMessage(
              title: uiText(
                context,
                zh: '内容加载失败',
                en: 'Failed to load content',
              ),
              message: error!,
              tone: AppMessageTone.error,
              action: onRetry == null
                  ? null
                  : TextButton(
                      onPressed: onRetry,
                      child: Text(uiText(context, zh: '重试', en: 'Retry')),
                    ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
