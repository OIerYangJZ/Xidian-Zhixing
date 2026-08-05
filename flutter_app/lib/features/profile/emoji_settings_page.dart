import 'package:flutter/material.dart';

import '../../core/emoji/emoji_catalog.dart';
import '../../core/emoji/emoji_settings_store.dart';
import '../../core/l10n/ui_text.dart';

class EmojiSettingsPage extends StatelessWidget {
  const EmojiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EmojiSettingsStore store = EmojiSettingsStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '表情设置', en: 'Emoji settings')),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      title: Text(
                        uiText(context, zh: '启用表情功能', en: 'Enable emoji'),
                      ),
                      subtitle: Text(
                        uiText(
                          context,
                          zh: '发帖、评论回复、私聊输入时可选择表情',
                          en:
                              'Pick emoji when posting, replying, or messaging',
                        ),
                      ),
                      value: store.enabled,
                      onChanged: (bool value) => store.setEnabled(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        uiText(context, zh: '常用表情', en: 'Frequently used'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        uiText(
                          context,
                          zh:
                              '已选 ${store.favorites.length}/${EmojiSettingsStore.maxFavorites}。点按可取消，再点其他可加入。',
                          en:
                              '${store.favorites.length}/${EmojiSettingsStore.maxFavorites} selected. Tap to remove, tap another to add.',
                        ),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EmojiCatalog.all.map((String emoji) {
                          final bool selected = store.favorites.contains(emoji);
                          return FilterChip(
                            selected: selected,
                            label: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            onSelected: store.enabled
                                ? (_) async {
                                    final bool success = await store
                                        .toggleFavorite(emoji);
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            uiText(
                                              context,
                                              zh: '常用表情最多 16 个',
                                              en:
                                                  'You can keep up to 16 favorites',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => store.resetDefaults(),
                        icon: const Icon(Icons.restore),
                        label: Text(
                          uiText(
                            context,
                            zh: '恢复默认表情设置',
                            en: 'Restore default emoji settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
