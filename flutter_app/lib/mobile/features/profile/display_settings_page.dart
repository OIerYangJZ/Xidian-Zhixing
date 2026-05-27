import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class DisplaySettingsPage extends ConsumerStatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  ConsumerState<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends ConsumerState<DisplaySettingsPage> {
  static const _themeOptions = [
    ('zhushachi', '朱砂赤', Color(0xFFB23A2E)),
    ('yanzhihong', '胭脂红', Color(0xFFB8324A)),
    ('chitaonuan', '赤陶暖', Color(0xFFB85B3E)),
    ('zaonihong', '枣泥红', Color(0xFF8F2F2C)),
    ('xuanzhizhu', '宣纸朱', Color(0xFFC43A2F)),
    ('zhuqing', '竹青', Color(0xFF4F8A5F)),
    ('ouhezi', '藕荷紫', Color(0xFF8B6F9E)),
    ('xingrenhuang', '杏仁黄', Color(0xFFC28A3A)),
    ('haiyanqing', '海盐青', Color(0xFF5B9EA6)),
    ('mohui', '墨灰', Color(0xFF4F5552)),
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
              final (key, name, color) = option;
              final selected = key == currentKey;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
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
              title: '简体中文',
              locale: const Locale('zh', 'CN'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('zh', 'CN'), ctx),
            ),
            _LocaleOption(
              title: '繁體中文',
              locale: const Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hant',
              ),
              current: currentLocale,
              onTap: () => _setLocale(
                const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                ),
                ctx,
              ),
            ),
            _LocaleOption(
              title: 'English',
              locale: const Locale('en', 'US'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('en', 'US'), ctx),
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
    final code = loc.scriptCode != null && loc.scriptCode!.isNotEmpty
        ? '${loc.languageCode}_${loc.scriptCode}'
        : '${loc.languageCode}_${loc.countryCode ?? ''}';
    if (code == 'zh_CN') return '简体中文';
    if (code == 'zh_Hant' || code == 'zh_TW') return '繁體中文';
    if (code == 'en_US' || code == 'en_') return 'English';
    return '${loc.languageCode}_${loc.countryCode ?? ''}';
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('界面设置'),
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
              title: '多语言',
              subtitle: _localeLabel(settings.locale ?? const Locale('zh', 'CN')),
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
    final selected =
        locale.languageCode == current?.languageCode &&
        locale.countryCode == current?.countryCode;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
      onTap: onTap,
    );
  }
}
