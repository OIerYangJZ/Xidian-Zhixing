import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';

/// 设置: the account card, then 账号 / 偏好 / 支持 lists and 退出登录.
class SettingsMainPage extends ConsumerStatefulWidget {
  const SettingsMainPage({super.key});

  @override
  ConsumerState<SettingsMainPage> createState() => _SettingsMainPageState();
}

class _SettingsMainPageState extends ConsumerState<SettingsMainPage> {
  Future<void> _logout() async {
    final bool confirmed = await zxConfirm(
      context,
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      confirmLabel: '退出',
      cancelLabel: '取消',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (error) {
      if (mounted) zxShowToast(context, '退出失败：$error');
      return;
    }
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final user = AuthStore.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (user != null) ...[
              ZxCard(
                key: const Key('mobile-settings-account'),
                padding: const EdgeInsets.all(16),
                onTap: () => context.push('/profile/edit'),
                child: Row(
                  children: [
                    AvatarWidget(
                      avatarUrl: user.avatarUrl,
                      nickname: user.nickname,
                      radius: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nickname,
                            style: ZxType.title.copyWith(color: t.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '编辑资料',
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.text3),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            ZxListSection(
              title: '账号',
              children: [
                ZxListItem(
                  key: const Key('mobile-settings-security'),
                  icon: Icons.lock_outline_rounded,
                  title: '账号与安全',
                  subtitle: '统一认证、用户等级、注销账号',
                  onTap: () => context.push('/profile/settings/account'),
                ),
                ZxListItem(
                  key: const Key('mobile-settings-privacy'),
                  icon: Icons.shield_outlined,
                  title: '隐私',
                  subtitle: '私信权限、可联系状态、屏蔽名单',
                  onTap: () => context.push('/profile/settings/privacy'),
                ),
                ZxListItem(
                  key: const Key('mobile-settings-notifications'),
                  icon: Icons.notifications_none_rounded,
                  title: '通知',
                  subtitle: '评论、回复、点赞等提醒',
                  onTap: () => context.push('/profile/settings/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ZxListSection(
              title: '偏好',
              children: [
                ZxListItem(
                  key: const Key('mobile-settings-display'),
                  icon: Icons.palette_outlined,
                  title: '显示',
                  subtitle: '深浅模式、主题配色、语言',
                  onTap: () => context.push('/profile/settings/display'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ZxListSection(
              title: '支持',
              children: [
                ZxListItem(
                  icon: Icons.mail_outline_rounded,
                  title: '帮助与反馈',
                  onTap: () => context.push('/profile/help-feedback'),
                ),
                ZxListItem(
                  key: const Key('mobile-settings-about'),
                  icon: Icons.info_outline_rounded,
                  title: '关于西电知行',
                  subtitle: '版本更新、用户协议与隐私政策',
                  onTap: () => context.push('/profile/settings/about'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ZxButton(
              key: const Key('mobile-settings-logout'),
              label: '退出登录',
              variant: ZxButtonVariant.secondary,
              expand: true,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
