import 'package:flutter/material.dart';

import '../../core/config/app_brand.dart';
import '../../core/theme/shared_colors.dart';

class ReportGuidelinesPage extends StatelessWidget {
  const ReportGuidelinesPage({super.key});

  static const String _title = '举报说明';
  static const String _lastUpdated = '2026年3月20日';

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: '为什么要举报',
            icon: Icons.help_outline,
            iconColor: Theme.of(context).colorScheme.primary,
            content:
                '${AppBrand.displayName}是一个大家共同维护的社区。当您发现违规内容时，一键举报可以帮助我们快速处理，共同维护良好的社区环境。\n\n'
                '您的每一次举报都是对社区秩序的守护，感谢您的参与！',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '一、举报流程',
            icon: Icons.route_outlined,
            iconColor: colors.success,
            content:
                '【步骤一】找到举报入口\n'
                '• 在帖子详情页右下角点击"更多"按钮（三个点图标）\n'
                '• 在展开菜单中选择"举报"\n\n'
                '【步骤二】选择举报原因\n'
                '• 根据内容性质选择对应的举报类型\n'
                '• 可选：补充详细的举报说明（有助于更快处理）\n\n'
                '【步骤三】提交举报\n'
                '• 点击"提交"按钮\n'
                '• 系统将显示"举报成功"提示\n\n'
                '【步骤四】等待处理\n'
                '• 管理员将在24小时内审核处理\n'
                '• 处理结果可在"我的举报"中查看',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '二、举报类型说明',
            icon: Icons.list_alt_outlined,
            iconColor: colors.primary,
            content:
                '请选择最准确的举报类型，以便我们快速处理：\n\n'
                '【违法违规】\n'
                '• 违反法律法规\n'
                '• 危害国家安全\n'
                '• 传播邪教迷信\n\n'
                '【色情低俗】\n'
                '• 淫秽色情内容\n'
                '• 暴力血腥内容\n'
                '• 低俗擦边内容\n\n'
                '【人身攻击】\n'
                '• 侮辱诽谤他人\n'
                '• 恶意骚扰\n'
                '• 造谣传谣\n\n'
                '【侵犯隐私】\n'
                '• 泄露他人个人信息\n'
                '• 未经允许公开聊天记录\n'
                '• 人肉搜索\n\n'
                '【垃圾广告】\n'
                '• 商业广告推广\n'
                '• 恶意刷屏\n'
                '• 无关链接\n\n'
                '【其他违规】\n'
                '• 不属于以上类型但确实违规的内容',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '三、举报注意事项',
            icon: Icons.tips_and_updates_outlined,
            iconColor: colors.warning,
            isWarning: true,
            content:
                '【正确举报】\n'
                '• 举报内容须确为违规，不要恶意举报正常内容\n'
                '• 选择准确的举报类型\n'
                '• 提供必要的补充说明（尤其是"其他违规"类型）\n'
                '• 保留相关证据截图\n\n'
                '【错误示范】\n'
                '• 因观点不同而举报（观点分歧不等于违规）\n'
                '• 恶意重复举报同一内容\n'
                '• 举报虚假违规内容\n'
                '• 打击报复性举报\n\n'
                '【后果提示】\n'
                '• 恶意举报将被记录\n'
                '• 多次恶意举报可能导致功能限制\n'
                '• 诬告陷害需承担相应责任',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '四、处理结果说明',
            icon: Icons.check_circle_outline,
            iconColor: colors.info,
            content:
                '管理员审核后，处理结果分为以下几种：\n\n'
                '【内容删除】\n'
                '确认内容违规，已删除处理。\n\n'
                '【无法认定】\n'
                '经审核，该内容暂未发现明显违规，将保留处理。\n\n'
                '【证据不足】\n'
                '举报证据不足，无法确认违规。\n\n'
                '【恶意举报】\n'
                '经审核，确认为恶意举报，将对举报人进行处理。\n\n'
                '您可以在"我的举报"中查看所有举报的处理状态和结果。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '五、举报处理时长',
            icon: Icons.timer_outlined,
            iconColor: colors.mutedInk,
            content:
                '【一般情况】\n'
                '• 工作时间（工作日9:00-18:00）：平均处理时长 2-6 小时\n'
                '• 非工作时间：平均处理时长 12-24 小时\n\n'
                '【特殊情况】\n'
                '• 紧急情况（如涉及人身安全）：将优先处理\n'
                '• 复杂情况（如需进一步核实）：可能需要更长时间\n\n'
                '【紧急求助】\n'
                '如遇紧急情况（如威胁人身安全），请同时联系学校保卫处或报警。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '六、举报人保护',
            icon: Icons.security_outlined,
            iconColor: colors.success,
            content:
                '我们高度重视举报人的隐私和安全：\n\n'
                '• 您的举报记录受到严格保护，不会向被举报人透露\n'
                '• 举报人的身份信息受到加密存储\n'
                '• 我们对任何打击报复行为零容忍\n'
                '• 如遭遇打击报复，请及时向我们反馈\n\n'
                '如发现被举报人有任何报复行为，请截图保存证据并重新举报，管理员将优先处理。',
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: '七、联系我们',
            icon: Icons.headset_mic_outlined,
            iconColor: colors.primary,
            content:
                '如果您在举报过程中遇到问题，或对处理结果有异议，可通过以下方式联系我们：\n\n'
                '• 在"我的举报"页面查看详情并留言反馈\n'
                '• 发送邮件至平台管理员邮箱\n'
                '• 通过站内私信联系管理员\n\n'
                '我们会认真对待每一条反馈。',
          ),
          const SizedBox(height: 32),
          _buildFooter(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colors.primarySubtle,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '最后更新：$_lastUpdated',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    bool isWarning = false,
  }) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning
            ? colors.warning.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isWarning
            ? Border.all(color: colors.warning.withValues(alpha: 0.2))
            : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isWarning
                        ? colors.warning
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isWarning
                  ? colors.warning
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AppBrand.displayName} · 校园匿名社交平台\n文明社区，你我共建。感谢您的每一次举报！',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
