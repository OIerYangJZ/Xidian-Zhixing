import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/shared_colors.dart';

class ThemeDropdown extends StatelessWidget {
  const ThemeDropdown({
    super.key,
    required this.themeKey,
    required this.locale,
    required this.onChanged,
    this.compact = false,
    this.expanded = false,
  });

  final String themeKey;
  final Locale locale;
  final ValueChanged<String> onChanged;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppColorThemeOption selected = AppColorThemes.optionFor(themeKey);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      label: locale.languageCode == 'en'
          ? 'Color theme: ${selected.labelFor(locale)}'
          : '配色主题：${selected.labelFor(locale)}',
      button: true,
      child: Container(
        height: compact ? 44 : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: ValueKey<String>(themeKey),
            value: themeKey,
            isExpanded: expanded,
            borderRadius: BorderRadius.circular(AppRadii.small),
            menuWidth: compact ? 236 : null,
            dropdownColor: colors.surface,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            menuMaxHeight: 320,
            selectedItemBuilder: (BuildContext context) {
              return AppColorThemes.options
                  .map(
                    (AppColorThemeOption option) => Align(
                      alignment: Alignment.centerLeft,
                      child: compact
                          ? _ThemeSwatches(colors: option.previewColors)
                          : _ThemeChoiceLabel(
                              option: option,
                              locale: locale,
                              showDescription: expanded,
                            ),
                    ),
                  )
                  .toList();
            },
            items: AppColorThemes.options
                .map(
                  (AppColorThemeOption option) => DropdownMenuItem<String>(
                    value: option.key,
                    child: Row(
                      children: <Widget>[
                        _ThemeSwatches(colors: option.previewColors),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: _ThemeChoiceLabel(
                            option: option,
                            locale: locale,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceLabel extends StatelessWidget {
  const _ThemeChoiceLabel({
    required this.option,
    required this.locale,
    this.showDescription = false,
  });

  final AppColorThemeOption option;
  final Locale locale;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    if (!showDescription) {
      return Text(
        option.labelFor(locale),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          option.labelFor(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          option.descriptionFor(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors
          .map(
            (Color color) => Container(
              width: 13,
              height: 13,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.7,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
