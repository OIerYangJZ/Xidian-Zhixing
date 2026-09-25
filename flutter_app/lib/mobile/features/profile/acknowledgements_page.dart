import 'package:flutter/material.dart';

import 'package:xdu_treehole_web/design_system/design_system.dart';

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});

  static const List<String> _thanks = <String>[
    '感谢所有参与测试、反馈与内容治理的同学。',
    '感谢为西电知行提供设计、产品、开发和运维支持的成员。',
    '感谢每一位提交建议和错误报告的用户。',
  ];

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('致谢')),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ZxHeroWash(
              borderRadius: ZxRadius.cardAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 40,
                      color: t.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '感谢每一位参与建设西电知行的人',
                      textAlign: TextAlign.center,
                      style: ZxType.headline.copyWith(
                        fontSize: 20,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这个项目仍在持续迭代。每一次测试、反馈、建议和修复，都让它更接近真正可用。',
                      textAlign: TextAlign.center,
                      style: ZxType.body.copyWith(color: t.text2, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ZxListSection(
              children: [
                for (final String item in _thanks)
                  ZxListItem(icon: Icons.check_rounded, title: item),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
