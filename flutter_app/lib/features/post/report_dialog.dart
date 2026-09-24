import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';

/// What the user chose in [showReportDialog].
class ReportChoice {
  const ReportChoice({required this.reason, this.description});

  /// Sent to the API as is, so always the Chinese label.
  final String reason;
  final String? description;
}

/// Asks for a report reason and optional details. Null when cancelled.
Future<ReportChoice?> showReportDialog(BuildContext context) {
  return showDialog<ReportChoice>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
}

// The value sent to the API stays Chinese; only the label is localized.
const List<(String, String)> _reasons = <(String, String)>[
  ('垃圾广告', 'Spam or advertising'),
  ('违法违规', 'Illegal content'),
  ('色情低俗', 'Sexual or vulgar content'),
  ('人身攻击', 'Personal attack'),
  ('虚假信息', 'Misinformation'),
  ('侵犯隐私', 'Privacy violation'),
  ('其他', 'Other'),
];

/// Owns its controller, so the text field keeps it through the dialog's exit
/// animation.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _description = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(uiText(context, zh: '举报', en: 'Report')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(uiText(context, zh: '请选择举报原因：', en: 'Choose a reason:')),
            const SizedBox(height: 8),
            for (final (String, String) reason in _reasons)
              RadioListTile<String>(
                title: Text(uiText(context, zh: reason.$1, en: reason.$2)),
                value: reason.$1,
                // ignore: deprecated_member_use
                groupValue: _reason,
                // ignore: deprecated_member_use
                onChanged: (String? value) => setState(() => _reason = value),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  zh: '补充说明（可选）',
                  en: 'Additional details (optional)',
                ),
                hintText: uiText(
                  context,
                  zh: '请详细描述举报原因',
                  en: 'Describe the issue in more detail',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, zh: '取消', en: 'Cancel')),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () {
                  final String details = _description.text.trim();
                  Navigator.of(context).pop(
                    ReportChoice(
                      reason: _reason!,
                      description: details.isEmpty ? null : details,
                    ),
                  );
                },
          child: Text(uiText(context, zh: '确认举报', en: 'Submit report')),
        ),
      ],
    );
  }
}
