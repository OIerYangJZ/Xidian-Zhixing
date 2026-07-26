import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../auth/login_page.dart';
import '../auth/reset_password_page.dart';
import '../campus/campus_auth_center_page.dart';

/// Account operations formerly embedded in the profile screen now live in
/// Settings, keeping the public profile free of editing controls.
class AccountSettingsPanel extends StatefulWidget {
  const AccountSettingsPanel({super.key});

  @override
  State<AccountSettingsPanel> createState() => _AccountSettingsPanelState();
}

class _AccountSettingsPanelState extends State<AccountSettingsPanel> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _backgroundUrlController =
      TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String _gender = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarUrlController.dispose();
    _bioController.dispose();
    _backgroundUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppStatePanel(
        icon: Icons.manage_accounts_outlined,
        title: '正在加载账户设置',
        message: '正在读取账户资料。',
      );
    }
    final UserProfile? profile = _profile;
    if (profile == null) {
      return AppStatePanel(
        icon: Icons.error_outline_rounded,
        title: '账户设置加载失败',
        message: _error ?? '账户资料暂时不可用。',
        action: FilledButton(onPressed: _loadProfile, child: const Text('重试')),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxxl,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text('账户与资料', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: '个人资料', child: _profileEditor(profile)),
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: '账户', child: _accountActions(profile)),
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: '账户操作', child: _dangerActions(profile)),
          ],
        ),
      ),
    );
  }

  Widget _profileEditor(UserProfile profile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _AccountIdentity(profile: profile),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _nicknameController,
        enabled: !_saving,
        decoration: AppInput.decoration(hintText: '昵称'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _avatarUrlController,
        enabled: !_saving,
        keyboardType: TextInputType.url,
        decoration: AppInput.decoration(hintText: '头像链接'),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: _saving ? null : _pickAndUploadAvatar,
        child: const Text('上传头像'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _bioController,
        enabled: !_saving,
        maxLines: 3,
        maxLength: 100,
        decoration: AppInput.decoration(hintText: '个人简介'),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: AppInput.decoration(hintText: '性别'),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: '', child: Text('不显示')),
          DropdownMenuItem<String>(value: '男', child: Text('男')),
          DropdownMenuItem<String>(value: '女', child: Text('女')),
        ],
        onChanged: _saving
            ? null
            : (String? value) => setState(() => _gender = value ?? ''),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _backgroundUrlController,
        enabled: !_saving,
        keyboardType: TextInputType.url,
        decoration: AppInput.decoration(hintText: '主页背景图链接'),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: _saving ? null : _pickAndUploadBackgroundImage,
        child: const Text('上传主页背景图'),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _saving ? null : _saveProfile,
        child: Text(_saving ? '正在保存' : '保存资料'),
      ),
    ],
  );

  Widget _accountActions(UserProfile profile) => Column(
    children: <Widget>[
      _SettingsActionRow(
        icon: Icons.lock_outline_rounded,
        title: '修改登录密码',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ResetPasswordPage(
              initialEmail: profile.email,
              lockEmail: profile.email.isNotEmpty,
            ),
          ),
        ),
      ),
      _SettingsActionRow(
        icon: Icons.account_balance_outlined,
        title: '校园账号管理',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CampusAuthCenterPage()),
        ),
      ),
    ],
  );

  Widget _dangerActions(UserProfile profile) => Column(
    children: <Widget>[
      _SettingsActionRow(
        icon: Icons.logout_rounded,
        title: '退出登录',
        onTap: _saving ? null : _logout,
      ),
      _SettingsActionRow(
        icon: Icons.delete_outline_rounded,
        title: profile.accountCancellationRequest?.status == 'pending'
            ? '注销申请审核中'
            : '申请注销账号',
        destructive: true,
        onTap:
            _saving || profile.accountCancellationRequest?.status == 'pending'
            ? null
            : _promptAccountCancellationRequest,
      ),
    ],
  );

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final UserProfile profile = await AppRepositories.users.fetchProfile();
      if (!mounted) return;
      AuthStore.instance.setCurrentUser(profile);
      setState(() {
        _profile = profile;
        _nicknameController.text = profile.nickname;
        _avatarUrlController.text = profile.avatarUrl;
        _bioController.text = profile.bio;
        _backgroundUrlController.text = profile.backgroundImageUrl;
        _gender = profile.gender;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '资料加载失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final List<PickedImageData> images = await pickImageFiles(multiple: false);
    if (!mounted || images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final PickedImageData image = images.first;
      final String url = await AppRepositories.users.uploadAvatar(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (mounted) _avatarUrlController.text = url;
    } catch (error) {
      _toast('头像上传失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadBackgroundImage() async {
    final List<PickedImageData> images = await pickImageFiles(multiple: false);
    if (!mounted || images.isEmpty) return;
    setState(() => _saving = true);
    try {
      final PickedImageData image = images.first;
      final String url = await AppRepositories.users.uploadBackgroundImage(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (mounted) _backgroundUrlController.text = url;
    } catch (error) {
      _toast('背景图上传失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    final UserProfile? profile = _profile;
    if (profile == null) return;
    final String nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _toast('请输入昵称');
      return;
    }
    setState(() => _saving = true);
    try {
      await AppRepositories.users.updateProfile(
        nickname: nickname,
        avatarUrl: _avatarUrlController.text.trim(),
        bio: _bioController.text.trim(),
        backgroundImageUrl: _backgroundUrlController.text.trim(),
        gender: _gender,
      );
      final UserProfile updated = profile.copyWith(
        nickname: nickname,
        avatarUrl: _avatarUrlController.text.trim(),
        bio: _bioController.text.trim(),
        backgroundImageUrl: _backgroundUrlController.text.trim(),
        gender: _gender,
      );
      AuthStore.instance.setCurrentUser(updated);
      if (mounted) setState(() => _profile = updated);
      _toast('资料已更新');
    } catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _promptAccountCancellationRequest() async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showAppDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('申请注销账号'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: AppInput.decoration(hintText: '申请说明（可选）'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    setState(() => _saving = true);
    try {
      await AppRepositories.users.submitAccountCancellationRequest(
        reason: reason,
      );
      await _loadProfile();
    } catch (error) {
      _toast('提交失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _saving = true);
    try {
      await AppRepositories.auth.logout();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _toast('退出失败：$error');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      child,
    ],
  );
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final String resolved = AppConfig.resolveUrl(profile.avatarUrl);
    final String initial = profile.nickname.trim().isEmpty
        ? '匿'
        : profile.nickname.trim().substring(0, 1);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.primarySubtle,
          backgroundImage: resolved.isEmpty ? null : NetworkImage(resolved),
          child: resolved.isEmpty ? Text(initial) : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.nickname,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final EditorialColors colors = EditorialColors.of(context);
    final Color foreground = destructive ? colors.danger : colors.ink;
    return Material(
      color: colors.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: TextStyle(color: foreground)),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: colors.faintInk),
            ],
          ),
        ),
      ),
    );
  }
}
