import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';
import 'zx_button.dart';

/// Empty or error state for a whole page or section (§06 页面状态): seal mark
/// or icon on the hero wash, a display-font title, a message, and one action.
class ZxStatePanel extends StatelessWidget {
  const ZxStatePanel({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });

  final String title;
  final String? message;

  /// Null shows the 知 seal.
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Error states use the danger hue and a secondary button (重试).
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget mark = icon == null
        ? Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.seal.withValues(alpha: 0.45)),
              color: t.sealSoft,
            ),
            child: Text(
              '知',
              style: TextStyle(
                fontFamily: ZxFonts.display,
                fontFamilyFallback: ZxFonts.displayFallback,
                fontSize: 30,
                color: t.seal,
              ),
            ),
          )
        : Icon(icon, size: 40, color: error ? t.danger : t.text3);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              mark,
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ZxType.headline.copyWith(fontSize: 20, color: t.text),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: ZxType.body.copyWith(color: t.text2),
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 20),
                ZxButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: error
                      ? ZxButtonVariant.secondary
                      : ZxButtonVariant.primary,
                  icon: error ? Icons.refresh_rounded : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder block with the 1.4s sweeping sheen (§06 骨架屏).
class ZxSkeleton extends StatefulWidget {
  const ZxSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = ZxRadius.badgeAll,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<ZxSkeleton> createState() => _ZxSkeletonState();
}

class _ZxSkeletonState extends State<ZxSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ZxMotion.shimmer,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: 'loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double x = reduceMotion ? 0 : _controller.value * 3 - 1.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: <Color>[t.bgSunk, t.surface, t.bgSunk],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum ZxMessageTone { info, success, warning, danger }

/// In-page message (§06 页内消息), e.g. 明暗模式自动跟随… or the first-message
/// limit in chat. Optional trailing action such as 重试.
class ZxInlineMessage extends StatelessWidget {
  const ZxInlineMessage({
    super.key,
    required this.message,
    this.tone = ZxMessageTone.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ZxMessageTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final (Color fg, Color bg, IconData icon) = switch (tone) {
      ZxMessageTone.info => (t.info, t.infoSoft, Icons.info_outline_rounded),
      ZxMessageTone.success => (
        t.success,
        t.successSoft,
        Icons.check_circle_outline_rounded,
      ),
      ZxMessageTone.warning => (
        t.warning,
        t.warningSoft,
        Icons.warning_amber_rounded,
      ),
      ZxMessageTone.danger => (
        t.danger,
        t.dangerSoft,
        Icons.error_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: ZxRadius.buttonAll),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: ZxType.caption.copyWith(color: fg)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Toast (§06 提示条): floating, with an optional undo-style action.
void zxShowToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

/// One entry in a [zxShowActionSheet].
class ZxSheetAction<T> {
  const ZxSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.danger = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool danger;
}

/// Bottom sheet of actions (§06, the post 「⋯」 menu). Resolves to the chosen
/// value, or null when dismissed or [cancelLabel] is tapped.
Future<T?> zxShowActionSheet<T>(
  BuildContext context, {
  required List<ZxSheetAction<T>> actions,
  required String cancelLabel,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (BuildContext sheetContext) {
      final ZxTokens t = ZxTokens.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ZxSheetAction<T> action in actions)
                ListTile(
                  leading: action.icon == null
                      ? null
                      : Icon(
                          action.icon,
                          color: action.danger ? t.danger : t.text2,
                        ),
                  title: Text(
                    action.label,
                    style: ZxType.body.copyWith(
                      color: action.danger ? t.danger : t.text,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(action.value),
                ),
              const SizedBox(height: 8),
              ZxButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(sheetContext).pop(),
                variant: ZxButtonVariant.secondary,
                expand: true,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Confirmation dialog (§06 弹窗). True only when [confirmLabel] is tapped.
Future<bool> zxConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        ZxButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          variant: ZxButtonVariant.secondary,
        ),
        ZxButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          variant: danger ? ZxButtonVariant.danger : ZxButtonVariant.primary,
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
