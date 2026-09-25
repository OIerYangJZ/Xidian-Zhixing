import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/design_system/design_system.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .updatePrivacy(
            allowStrangerDm: allowStrangerDm,
            showContactable: showContactable,
          );
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(
          allowStrangerDm: allowStrangerDm,
          showContactable: showContactable,
        );
      });
      _showToast('隐私设置已更新');
    } catch (e) {
      if (!mounted) return;
      _showToast('设置失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    zxShowToast(context, message);
  }

  Widget _switch({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ZxListItem(
      key: key,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: _saving ? null : onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? p = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('隐私')),
      body: ZxPaper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || p == null
            ? ZxStatePanel(
                error: true,
                icon: Icons.error_outline_rounded,
                title: '隐私设置加载失败',
                message: _error,
                actionLabel: '重试',
                onAction: _loadProfile,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  ZxListSection(
                    title: '私信与联系',
                    children: [
                      _switch(
                        key: const Key('mobile-privacy-stranger-dm'),
                        title: '允许陌生人私信',
                        subtitle: '关闭后，别人不能从你的主页或帖子给你发起私信',
                        value: p.allowStrangerDm,
                        onChanged: (bool v) => _updatePrivacy(
                          allowStrangerDm: v,
                          showContactable: p.showContactable,
                        ),
                      ),
                      _switch(
                        key: const Key('mobile-privacy-contactable'),
                        title: '显示「可联系」状态',
                        subtitle: '开启后，你的主页会显示可以联系你',
                        value: p.showContactable,
                        onChanged: (bool v) => _updatePrivacy(
                          allowStrangerDm: p.allowStrangerDm,
                          showContactable: v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ZxListSection(
                    title: '屏蔽',
                    children: [
                      ZxListItem(
                        key: const Key('mobile-privacy-blocked'),
                        icon: Icons.block_rounded,
                        title: '屏蔽名单',
                        subtitle: '被屏蔽的人不能给你发私信',
                        onTap: () => context.push('/profile/settings/blocked'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
