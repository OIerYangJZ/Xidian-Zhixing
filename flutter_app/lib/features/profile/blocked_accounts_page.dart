import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../repositories/app_repositories.dart';

/// 黑名单管理: accounts you blocked, each with 解除屏蔽.
class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({super.key});

  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  List<Map<String, dynamic>>? _blocks;
  String? _error;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<Map<String, dynamic>> blocks = await AppRepositories.users
          .fetchBlocks();
      if (mounted) setState(() => _blocks = blocks);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _unblock(String userId, String name) async {
    final bool confirmed = await zxConfirm(
      context,
      title: uiText(context, zh: '解除屏蔽？', en: 'Unblock?'),
      message: uiText(
        context,
        zh: '解除后，「$name」可以再次给你发消息。',
        en: '"$name" will be able to message you again.',
      ),
      confirmLabel: uiText(context, zh: '解除屏蔽', en: 'Unblock'),
      cancelLabel: uiText(context, zh: '取消', en: 'Cancel'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(userId));
    try {
      await AppRepositories.users.unblockUser(userId);
      if (!mounted) return;
      setState(() {
        _blocks = _blocks
            ?.where((Map<String, dynamic> b) => '${b['id'] ?? ''}' != userId)
            .toList();
      });
      zxShowToast(context, uiText(context, zh: '已解除屏蔽', en: 'Unblocked'));
    } catch (error) {
      if (mounted) {
        zxShowToast(
          context,
          uiText(context, zh: '解除屏蔽失败：$error', en: 'Could not unblock: $error'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    final ZxTokens t = ZxTokens.of(context);
    final List<Map<String, dynamic>>? blocks = _blocks;

    Widget body;
    if (blocks == null) {
      body = _error == null
          ? const Center(child: CircularProgressIndicator())
          : ZxStatePanel(
              icon: Icons.error_outline_rounded,
              error: true,
              title: text('黑名单加载失败', 'Could not load blocked accounts'),
              message: _error,
              actionLabel: text('重试', 'Retry'),
              onAction: _load,
            );
    } else if (blocks.isEmpty) {
      body = ZxStatePanel(
        icon: Icons.block_rounded,
        title: text('暂无屏蔽用户', 'No blocked accounts'),
        message: text(
          '在会话或用户主页里可以屏蔽对方',
          'You can block someone from a chat or their profile.',
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ZxCard(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < blocks.length; i++) ...<Widget>[
                      if (i > 0) Divider(height: 1, color: t.line),
                      Builder(
                        builder: (BuildContext context) {
                          final String id = '${blocks[i]['id'] ?? ''}';
                          final String name =
                              '${blocks[i]['nickname'] ?? text('西电同学', 'Student')}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: <Widget>[
                                ZxAvatar(
                                  name: name,
                                  imageUrl: '${blocks[i]['avatarUrl'] ?? ''}',
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: ZxType.label.copyWith(color: t.text),
                                  ),
                                ),
                                ZxButton(
                                  label: text('解除屏蔽', 'Unblock'),
                                  variant: ZxButtonVariant.secondary,
                                  small: true,
                                  loading: _busy.contains(id),
                                  onPressed: _busy.contains(id)
                                      ? null
                                      : () => _unblock(id, name),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(text('黑名单管理', 'Blocked accounts'))),
      body: ZxPaper(child: body),
    );
  }
}
