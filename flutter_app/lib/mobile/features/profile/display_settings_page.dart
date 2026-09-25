import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/design_system.dart';
import '../../core/state/mobile_providers.dart';

class DisplaySettingsPage extends ConsumerStatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  ConsumerState<DisplaySettingsPage> createState() =>
      _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends ConsumerState<DisplaySettingsPage> {
  Future<void> _setThemeKey(String key) async {
    await ref.read(appSettingsProvider).setThemeKey(key);
  }

  Future<void> _setMode(ThemeMode mode) async {
    await ref.read(appSettingsProvider).setBrightness(mode);
  }

  Future<void> _setLocale(Locale locale) async {
    await ref.read(appSettingsProvider).setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final settings = ref.watch(appSettingsProvider);
    final Locale locale = Localizations.localeOf(context);
    final bool en = locale.languageCode == 'en';
    String text(String zh, String e) => en ? e : zh;

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        label,
        style: ZxType.caption.copyWith(
          color: t.text3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // Handoff M3. Android has one post layout, so that group is left out.
    return Scaffold(
      appBar: AppBar(title: Text(text('显示设置', 'Display'))),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            heading(text('深浅模式', 'Appearance')),
            Row(
              children: [
                for (final (ThemeMode mode, String zh, String e)
                    in const <(ThemeMode, String, String)>[
                      (ThemeMode.system, '跟随系统', 'System'),
                      (ThemeMode.light, '浅色', 'Light'),
                      (ThemeMode.dark, '深色', 'Dark'),
                    ]) ...[
                  if (mode != ThemeMode.system) const SizedBox(width: 10),
                  Expanded(
                    child: _ModeCard(
                      key: Key('display-mode-${mode.name}'),
                      mode: mode,
                      label: text(zh, e),
                      selected: settings.themeMode == mode,
                      onTap: () => _setMode(mode),
                    ),
                  ),
                ],
              ],
            ),
            heading(text('主题配色', 'Color theme')),
            ZxCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  for (int i = 0; i < zxThemes.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.line),
                    _ThemeRow(
                      theme: zxThemes[i],
                      en: en,
                      selected: settings.themeKey == zxThemes[i].key,
                      onTap: () => _setThemeKey(zxThemes[i].key),
                    ),
                  ],
                ],
              ),
            ),
            heading(text('语言', 'Language')),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('简体中文')),
                ButtonSegment<bool>(value: true, label: Text('English')),
              ],
              selected: <bool>{en},
              onSelectionChanged: (Set<bool> v) => _setLocale(
                v.first ? const Locale('en') : const Locale('zh', 'CN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature light / dark page; 跟随系统 shows both halves.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget half(bool dark) => Expanded(
      child: Container(
        color: dark ? const Color(0xFF1C1C1A) : const Color(0xFFFAF8F3),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 4,
              color: dark ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 5),
            Container(
              width: 16,
              height: 3,
              color: dark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
    return Material(
      color: selected ? t.primarySoft : t.surface,
      borderRadius: ZxRadius.cardAll,
      child: InkWell(
        borderRadius: ZxRadius.cardAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            borderRadius: ZxRadius.cardAll,
            border: Border.all(
              color: selected ? t.primary : t.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: ZxRadius.badgeAll,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (mode != ThemeMode.dark) half(false),
                      if (mode != ThemeMode.light) half(true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: ZxType.caption.copyWith(
                  fontSize: 13,
                  color: selected ? t.primary : t.text2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.en,
    required this.selected,
    required this.onTap,
  });

  final ZxThemeInfo theme;
  final bool en;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget swatch(Color c, {bool round = false}) => Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: c,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(4),
        border: Border.all(color: t.line),
      ),
    );
    return InkWell(
      key: Key('display-theme-${theme.key}'),
      borderRadius: ZxRadius.buttonAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            swatch(theme.light.bg),
            swatch(theme.light.primary),
            swatch(theme.light.accent, round: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? theme.labelEn : theme.labelZh,
                    style: ZxType.label.copyWith(color: t.text),
                  ),
                  Text(
                    en ? theme.descriptionEn : theme.descriptionZh,
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: t.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 14, color: t.onPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
