import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xdu_treehole_web/l10n/generated/app_localizations.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class DisplaySettingsPage extends ConsumerStatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  ConsumerState<DisplaySettingsPage> createState() =>
      _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends ConsumerState<DisplaySettingsPage> {
  static const _themeOptions = [
    ('zhushachi', '朱砂赤'),
    ('yanzhihong', '胭脂红'),
    ('chitaonuan', '赤陶暖'),
    ('zaonihong', '枣泥红'),
    ('xuanzhizhu', '宣纸朱'),
    ('zhuqing', '竹青'),
    ('ouhezi', '藕荷紫'),
    ('xingrenhuang', '杏仁黄'),
    ('haiyanqing', '海盐青'),
    ('mohui', '墨灰'),
  ];

  void _showThemeDialog() {
    final currentKey = ref.read(appSettingsProvider).themeKey;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('外观主题'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _themeOptions.map((option) {
              final (key, name) = option;
              final selected = key == currentKey;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: MobileTheme.themes[key]!.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(name),
                trailing: selected
                    ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
                    : null,
                onTap: () => _setThemeKey(key, ctx),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _setThemeKey(String key, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setThemeKey(key);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_themeLabel(key)}');
  }

  String _themeLabel(String key) {
    for (final option in _themeOptions) {
      if (option.$1 == key) return option.$2;
    }
    return key;
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(appSettingsProvider).locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LocaleOption(
              title: '中文',
              locale: const Locale('zh', 'CN'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('zh', 'CN'), ctx),
            ),
            _LocaleOption(
              title: 'English',
              locale: const Locale('en'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('en'), ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale loc, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setLocale(loc);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_localeLabel(loc)}');
  }

  String _localeLabel(Locale loc) {
    return loc.languageCode == 'en' ? 'English' : '中文';
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final settings = ref.watch(appSettingsProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: colors.background,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTileCard([
            _buildListTile(
              icon: Icons.brightness_6_outlined,
              title: '外观主题',
              subtitle: _themeLabel(settings.themeKey),
              onTap: _showThemeDialog,
            ),
            _buildListTile(
              icon: Icons.language_outlined,
              title: l10n.language,
              subtitle: _localeLabel(
                settings.locale ?? const Locale('zh', 'CN'),
              ),
              onTap: _showLanguageDialog,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTileCard(List<Widget> children) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        children: List<Widget>.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(height: 0.5, indent: 56, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.title,
    required this.locale,
    required this.current,
    required this.onTap,
  });

  final String title;
  final Locale locale;
  final Locale? current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = locale.languageCode == current?.languageCode;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
      onTap: onTap,
    );
  }
}
