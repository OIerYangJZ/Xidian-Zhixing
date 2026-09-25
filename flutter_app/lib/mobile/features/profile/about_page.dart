import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import '../../features/update/app_update_controller.dart';
import '../../features/update/app_update_dialog.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  Future<void> _handleCheckUpdate() async {
    final controller = ref.read(appUpdateProvider);
    final hasUpdate = await controller.checkForUpdates(clearError: true);
    if (!mounted) return;
    if (hasUpdate && controller.latestRelease != null) {
      await showAppUpdateDialog(
        context,
        release: controller.latestRelease!,
        currentVersionLabel: controller.currentVersionLabel,
      );
      return;
    }
    if (controller.error != null && controller.error!.trim().isNotEmpty) {
      _showToast('检查更新失败：${controller.error}');
      return;
    }
    _showToast('当前已是最新版本');
  }

  String _updateSubtitle(AppUpdateController controller) {
    final current = '当前版本 ${controller.currentVersionLabel}';
    if (controller.hasUpdate && controller.latestRelease != null) {
      return '$current · 最新版本 ${controller.latestVersionLabel}';
    }
    return current;
  }

  void _showToast(String message) {
    if (!mounted) return;
    zxShowToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final updateController = ref.watch(appUpdateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('关于西电知行')),
      body: ZxPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ZxHeroWash(
              borderRadius: ZxRadius.cardAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const ZxAvatar.anonymous(name: '知', size: 68),
                    const SizedBox(height: 14),
                    Text(
                      '西电知行',
                      style: ZxType.display.copyWith(
                        fontSize: 26,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'XIDIAN ZHIXING',
                      style: ZxType.micro.copyWith(
                        color: t.text3,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '让校园里的真实声音被听见',
                      style: ZxType.body.copyWith(color: t.text2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '版本 ${updateController.currentVersionLabel}',
                      style: ZxType.caption.copyWith(color: t.text3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (updateController.supportsInAppUpdate) ...[
              ZxListSection(
                title: '版本',
                children: [
                  ZxListItem(
                    key: const Key('mobile-about-update'),
                    icon: Icons.system_update_alt_rounded,
                    title: '检查更新',
                    subtitle: _updateSubtitle(updateController),
                    trailing: updateController.checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : updateController.hasUpdate
                        ? ZxBadge.inProgress('有新版本')
                        : null,
                    onTap: updateController.checking
                        ? null
                        : _handleCheckUpdate,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            ZxListSection(
              title: '规则与隐私',
              children: [
                ZxListItem(
                  icon: Icons.description_outlined,
                  title: '用户协议',
                  onTap: () => context.push('/legal/terms'),
                ),
                ZxListItem(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  onTap: () => context.push('/legal/privacy'),
                ),
                ZxListItem(
                  icon: Icons.gavel_outlined,
                  title: '社区规范',
                  onTap: () => context.push('/legal/guidelines'),
                ),
                ZxListItem(
                  icon: Icons.flag_outlined,
                  title: '举报说明',
                  onTap: () => context.push('/legal/report'),
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
                  icon: Icons.favorite_border_rounded,
                  title: '致谢',
                  subtitle: '感谢每一位参与建设与反馈的同学',
                  onTap: () => context.push('/profile/acknowledgements'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2026 西电知行',
                style: ZxType.micro.copyWith(color: t.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
