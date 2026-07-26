import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.locale,
    required this.onChanged,
    this.compact = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool english = locale.languageCode == 'en';
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderSide border = BorderSide(color: colors.outline);

    return Semantics(
      label: english ? 'Language: English' : '语言：中文',
      button: true,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.fromBorderSide(border),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _LanguageOption(
              label: '中',
              selected: !english,
              compact: compact,
              onTap: () => onChanged(const Locale('zh', 'CN')),
            ),
            Container(width: 1, height: 20, color: colors.outline),
            _LanguageOption(
              label: 'EN',
              selected: english,
              compact: compact,
              onTap: () => onChanged(const Locale('en')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(minWidth: compact ? 42 : 48, minHeight: 42),
        color: selected ? colors.primary : Colors.transparent,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
