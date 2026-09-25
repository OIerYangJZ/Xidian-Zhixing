import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/design_system/design_system.dart';

/// 帮助与反馈: common questions that expand in place, the report entries, and
/// how to reach the admins. Open without signing in as well.
class HelpAndFeedbackPage extends StatelessWidget {
  const HelpAndFeedbackPage({super.key});

  static const List<(IconData, String, String)> _faq =
      <(IconData, String, String)>[
        (
          Icons.lock_outline_rounded,
          '登录失败怎么办？',
          '请在西电官方统一身份认证页面按提示处理；忘记密码请用官方页面的找回密码功能。',
        ),
        (
          Icons.verified_user_outlined,
          '需要单独注册吗？',
          '不需要。首次通过西电统一身份认证后，平台会自动创建账号。',
        ),
        (
          Icons.visibility_off_outlined,
          '如何匿名发帖？',
          '发帖时打开「匿名发布」，可以自定义匿名昵称，也可以点「随机」生成一个。',
        ),
        (
          Icons.mail_outline_rounded,
          '私信是怎么开始的？',
          '第一条消息会直接发给对方；对方回复之前只能发这一条，回复之后就可以自由聊天。',
        ),
        (
          Icons.block_rounded,
          '如何屏蔽某个用户？',
          '在对方主页或聊天页右上角选择「屏蔽」。屏蔽名单在「设置 · 隐私」里管理。',
        ),
        (
          Icons.flag_outlined,
          '举报后多久处理？',
          '管理员会在 24 小时内审核，处理结果可以在「我的举报」里查看。',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                '常见问题',
                style: ZxType.caption.copyWith(
                  color: t.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ZxCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < _faq.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.line),
                    Theme(
                      // No divider lines from the expansion itself.
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: Key('mobile-help-faq-$i'),
                        leading: Icon(_faq[i].$1, size: 20, color: t.primary),
                        title: Text(
                          _faq[i].$2,
                          style: ZxType.label.copyWith(color: t.text),
                        ),
                        iconColor: t.text3,
                        collapsedIconColor: t.text3,
                        childrenPadding: const EdgeInsets.fromLTRB(
                          56,
                          0,
                          16,
                          14,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(
                            _faq[i].$3,
                            style: ZxType.body.copyWith(
                              color: t.text2,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            ZxListSection(
              title: '举报',
              children: [
                ZxListItem(
                  icon: Icons.flag_outlined,
                  title: '举报说明',
                  subtitle: '了解举报受理与处理流程',
                  onTap: () => context.push('/legal/report'),
                ),
                ZxListItem(
                  icon: Icons.article_outlined,
                  title: '我的举报',
                  subtitle: '查看举报的处理状态',
                  onTap: () => context.push('/profile/reports'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ZxCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.primarySoft,
                      borderRadius: ZxRadius.buttonAll,
                    ),
                    child: Icon(
                      Icons.headset_mic_outlined,
                      color: t.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '仍有疑问？',
                          style: ZxType.label.copyWith(color: t.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '可以私信管理员，或发送邮件至平台管理员邮箱。',
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
