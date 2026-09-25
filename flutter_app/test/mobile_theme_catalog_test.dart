import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xdu_treehole_web/core/theme/shared_colors.dart';
import 'package:xdu_treehole_web/mobile/core/theme/mobile_colors.dart';
import 'package:xdu_treehole_web/mobile/core/theme/mobile_theme.dart';

void main() {
  // The settings page offers every AppColorThemes option, so the mobile app
  // must be able to build each one; a missing key used to throw on selection.
  for (final AppColorThemeOption option in AppColorThemes.options) {
    test('mobile app builds the ${option.key} theme', () {
      final ThemeData theme = MobileTheme.getThemeData(
        option.key,
        const Locale('zh', 'CN'),
      );
      final MobileColors colors = MobileColors.fromThemeKey(option.key);
      expect(theme.colorScheme.primary, colors.primary);
      final ThemeData dark = MobileTheme.getThemeData(
        option.key,
        const Locale('zh', 'CN'),
        brightness: Brightness.dark,
      );
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<MobileColors>()!.primary, dark.colorScheme.primary);
    });
  }
}
