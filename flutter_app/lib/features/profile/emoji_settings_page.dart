import 'package:flutter/material.dart';

import '../../core/emoji/emoji_catalog.dart';
import '../../core/emoji/emoji_settings_store.dart';
import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';

/// 表情设置: the on / off switch and the favourites shown first.
class EmojiSettingsPage extends StatelessWidget {
  const EmojiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final EmojiSettingsStore store = EmojiSettingsStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '表情设置', en: 'Emoji settings')),
      ),
      body: ZxPaper(
        child: AnimatedBuilder(
          animation: store,
          builder: (BuildContext context, Widget? child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                ZxListSection(
                  children: <Widget>[
                    ZxListItem(
                      key: const Key('emoji-enabled'),
                      icon: Icons.emoji_emotions_outlined,
                      title: uiText(context, zh: '启用表情功能', en: 'Enable emoji'),
                      subtitle: uiText(
                        context,
                        zh: '发帖、评论回复、私聊输入时可选择表情',
                        en: 'Pick emoji when posting, replying, or messaging',
                      ),
                      trailing: Switch(
                        value: store.enabled,
                        onChanged: (bool value) => store.setEnabled(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ZxListSection(
                  title: uiText(context, zh: '常用表情', en: 'Frequently used'),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            uiText(
                              context,
                              zh: '已选 ${store.favorites.length}/${EmojiSettingsStore.maxFavorites}。点按可取消，再点其他可加入。',
                              en: '${store.favorites.length}/${EmojiSettingsStore.maxFavorites} selected. Tap to remove, tap another to add.',
                            ),
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final String emoji in EmojiCatalog.all)
                                FilterChip(
                                  showCheckmark: false,
                                  selected: store.favorites.contains(emoji),
                                  label: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  onSelected: store.enabled
                                      ? (_) async {
                                          final bool ok = await store
                                              .toggleFavorite(emoji);
                                          if (!ok && context.mounted) {
                                            zxShowToast(
                                              context,
                                              uiText(
                                                context,
                                                zh: '常用表情最多 16 个',
                                                en: 'You can keep up to 16 favorites',
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ZxButton(
                            key: const Key('emoji-reset'),
                            label: uiText(
                              context,
                              zh: '恢复默认表情设置',
                              en: 'Restore default emoji settings',
                            ),
                            icon: Icons.restore_rounded,
                            variant: ZxButtonVariant.secondary,
                            onPressed: () => store.resetDefaults(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
