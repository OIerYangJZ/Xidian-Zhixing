import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';

/// Asks for an optional reason before a request (注销申请, 申请一级用户).
/// Null when cancelled, otherwise the trimmed text, possibly empty. The
/// dialog owns its controller, so nothing is disposed while it animates out.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String hint,
  required String confirmLabel,
  bool danger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      danger: danger,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String? message;
  final String hint;
  final String confirmLabel;
  final bool danger;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.message != null) ...<Widget>[
              Text(
                widget.message!,
                style: ZxType.body.copyWith(color: t.text2),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('reason-dialog-input'),
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  zh: '申请说明（可选）',
                  en: 'Reason (optional)',
                ),
                hintText: widget.hint,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        ZxButton(
          label: uiText(context, zh: '取消', en: 'Cancel'),
          variant: ZxButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ZxButton(
          key: const Key('reason-dialog-submit'),
          label: widget.confirmLabel,
          variant: widget.danger
              ? ZxButtonVariant.danger
              : ZxButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
