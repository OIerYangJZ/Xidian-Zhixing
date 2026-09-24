import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/theme/shared_colors.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';

double _contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  final double hi = x > y ? x : y;
  final double lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('design system offers exactly the themes users can already pick', () {
    expect(
      zxThemes.map((ZxThemeInfo t) => t.key).toSet(),
      AppColorThemes.options.map((AppColorThemeOption o) => o.key).toSet(),
    );
  });

  test('unknown theme keys fall back to the default instead of throwing', () {
    expect(zxThemeFor('no-such-theme').key, zxDefaultThemeKey);
  });

  for (final ZxThemeInfo theme in zxThemes) {
    for (final Brightness brightness in Brightness.values) {
      final String label = '${theme.key}/${brightness.name}';

      test('$label builds a theme carrying its tokens', () {
        final ThemeData data = ZxTheme.build(
          themeKey: theme.key,
          brightness: brightness,
        );
        final ZxTokens? tokens = data.extension<ZxTokens>();
        expect(tokens, isNotNull);
        expect(data.brightness, brightness);
        expect(data.colorScheme.primary, tokens!.primary);
        expect(data.scaffoldBackgroundColor, tokens.bg);
      });

      test('$label keeps component text at 4.5:1', () {
        final ZxPalette p = zxPaletteFor(theme.key, brightness);
        final Map<String, (Color, Color)> pairs = <String, (Color, Color)>{
          'neutral badge': (p.text2, p.bgSunk),
          'toast': (p.surface, p.text),
          'disabled button label': (p.text3, p.bgSunk),
          'danger list item': (p.danger, p.surface),
        };
        for (final Color hue in p.channels) {
          // Real-name avatar initial on its tint (see ZxAvatar._realName).
          pairs['avatar ${hue.toARGB32().toRadixString(16)}'] = (
            Color.lerp(hue, p.text, 0.3)!,
            Color.lerp(hue, p.surface, 0.82)!,
          );
        }
        for (final MapEntry<String, (Color, Color)> e in pairs.entries) {
          final double ratio = _contrast(e.value.$1, e.value.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${e.key} is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }
  }

  test('channel hue is stable per name', () {
    final ZxTokens t = ZxTokens(
      zxPaletteFor(zxDefaultThemeKey, Brightness.light),
    );
    expect(t.channelFor('学习交流'), t.channelFor('学习交流'));
    expect(t.channels, contains(t.channelFor('')));
  });

  testWidgets('anonymous avatars never link to a profile', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZxTheme.build(
          themeKey: zxDefaultThemeKey,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ZxAvatar(name: '林小舟', onTap: () => taps++),
              const ZxAvatar.anonymous(name: '安'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('林'));
    await tester.tap(find.text('安'));
    expect(taps, 1);
  });

  testWidgets('a loading button ignores taps', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZxTheme.build(
          themeKey: zxDefaultThemeKey,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: ZxButton(label: '发布帖子', loading: true, onPressed: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('发布帖子'));
    expect(taps, 0);
  });
}
