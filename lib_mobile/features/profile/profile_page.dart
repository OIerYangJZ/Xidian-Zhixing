import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../../lib/core/auth/auth_store.dart';

/// 个人中心页
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = AuthStore.instance.currentUser;

    return Scaffold(
      backgroundColor: MobileTheme.background,
      body: CustomScrollView(
        slivers: [
          // 顶部个人信息
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: MobileTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MobileTheme.primary.withValues(alpha: 0.1),
                      MobileTheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // 头像
                      GestureDetector(
                        onTap: () => context.push('/profile/edit'),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: MobileTheme.primary.withValues(alpha: 0.2),
                              child: user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        user.avatarUrl,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: MobileTheme.primary,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: MobileTheme.primary,
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: MobileTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 昵称
                      Text(
                        user?.nickname ?? '匿名同学',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: MobileTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 学号
                      Text(
                        user?.studentId ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: MobileTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            title: const Text('我的'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
          ),

          // 数据统计
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: MobileTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(label: '帖子', value: '5'),
                  _VerticalDivider(),
                  _StatItem(label: '评论', value: '12'),
                  _VerticalDivider(),
                  _StatItem(label: '收藏', value: '${user?.favoriteCount ?? 0}'),
                  _VerticalDivider(),
                  _StatItem(label: '等级', value: user?.userLevelLabel ?? 'Lv.1'),
                ],
              ),
            ),
          ),

          // 功能列表
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MobileTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.article_outlined,
                    title: '我的帖子',
                    onTap: () => context.push('/profile/posts'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.comment_outlined,
                    title: '我的评论',
                    onTap: () => context.push('/profile/comments'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.star_outline,
                    title: '我的收藏',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.flag_outlined,
                    title: '我的举报',
                    onTap: () => context.push('/profile/reports'),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 其他设置
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MobileTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.edit_outlined,
                    title: '编辑资料',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    title: '账号设置',
                    onTap: () => context.push('/profile/settings'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.help_outline,
                    title: '帮助与反馈',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MobileTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: MobileTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: MobileTheme.divider,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: MobileTheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: MobileTheme.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: MobileTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
