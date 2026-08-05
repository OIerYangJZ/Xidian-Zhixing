import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../../features/legal/report_guidelines_page.dart';
import '../auth/login_page.dart';
import 'emoji_settings_page.dart';
import 'settings_page.dart';
import '../me/my_comments_page.dart';
import '../me/my_favorites_page.dart';
import '../me/my_posts_page.dart';
import '../me/my_reports_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _backgroundUrlController =
      TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> refreshProfile() => _loadProfile();

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
        icon: Icons.person_outline_rounded,
        title: '正在加载个人资料',
        message: '正在同步账号、内容和隐私设置。',
      );
    }

    final UserProfile? loadedProfile = _profile;
    if (loadedProfile == null) {
      return AppStatePanel(
        icon: Icons.error_outline,
        title: '个人资料加载失败',
        message: _error ?? '服务端未返回有效的个人资料',
        action: FilledButton.tonalIcon(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    final UserProfile profile = loadedProfile;

    final AccountCancellationRequestSummary? cancellationRequest =
        profile.accountCancellationRequest;
    final UserLevelRequestSummary? levelUpgradeRequest =
        profile.levelUpgradeRequest;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: AppLayout.pagePadding(context),
          children: <Widget>[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppInlineMessage(
                  title: '资料未完全同步',
                  message: _error!,
                  tone: AppMessageTone.error,
                  action: TextButton(
                    onPressed: _saving ? null : _loadProfile,
                    child: const Text('重试'),
                  ),
                ),
              ),
            _buildProfileHero(profile),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('账号等级'),
                    subtitle: Text(
                      profile.isLevelOneUser
                          ? '当前为 ${profile.userLevelLabel}，可直接为帖子设置置顶时长'
                          : levelUpgradeRequest == null
                          ? '当前为 ${profile.userLevelLabel}，可向一级管理员申请升级'
                          : _levelUpgradeSubtitle(levelUpgradeRequest),
                    ),
                    trailing: Text(
                      profile.userLevelLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!profile.isLevelOneUser)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed:
                              _saving ||
                                  levelUpgradeRequest?.status == 'pending'
                              ? null
                              : _promptLevelUpgradeRequest,
                          icon: const Icon(Icons.arrow_circle_up_outlined),
                          label: Text(
                            levelUpgradeRequest?.status == 'pending'
                                ? '申请审核中'
                                : '申请成为一级用户',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '个人信息',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nicknameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: '用户昵称',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _avatarUrlController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: '头像 URL',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickAndUploadAvatar,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('选择图片并上传头像'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioController,
                      enabled: !_saving,
                      maxLines: 2,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: '个性签名',
                        hintText: '介绍一下自己吧',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: '性别',
                        prefixIcon: Icon(Icons.wc_outlined),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: '', child: Text('不显示')),
                        DropdownMenuItem<String>(value: '男', child: Text('男')),
                        DropdownMenuItem<String>(value: '女', child: Text('女')),
                      ],
                      onChanged: _saving
                          ? null
                          : (String? value) {
                              setState(() {
                                _gender = value ?? '';
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _backgroundUrlController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: '主页背景图 URL',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.wallpaper_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : _pickAndUploadBackgroundImage,
                        icon: const Icon(Icons.landscape_outlined),
                        label: const Text('选择图片并上传背景图'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? '保存中...' : '保存资料'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('我的帖子'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyPostsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.comment_bank_outlined),
                    title: const Text('我的评论'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyCommentsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('我的举报'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyReportsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('我的收藏'),
                    subtitle: Text('当前收藏帖子：${profile.favoriteCount}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyFavoritesPage(),
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      await _loadProfile();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('注销账号申请'),
                    subtitle: Text(
                      cancellationRequest == null
                          ? '提交后将进入管理员后台审核，通过后账号才会注销'
                          : _accountCancellationSubtitle(cancellationRequest),
                    ),
                    onTap: _saving || cancellationRequest?.status == 'pending'
                        ? null
                        : _promptAccountCancellationRequest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('允许陌生人私信'),
                    subtitle: const Text('关闭后，其他人无法通过你的公开主页或帖子给你发起私信'),
                    value: profile.allowStrangerDm,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            _updatePrivacy(
                              allowStrangerDm: value,
                              showContactable: profile.showContactable,
                            );
                          },
                  ),
                  SwitchListTile(
                    title: const Text('显示“可联系”状态'),
                    value: profile.showContactable,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            _updatePrivacy(
                              allowStrangerDm: profile.allowStrangerDm,
                              showContactable: value,
                            );
                          },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: const Text('黑名单管理'),
                    onTap: () => _toast('黑名单管理页下一步接入。'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_emotions_outlined),
                    title: const Text('表情设置'),
                    subtitle: const Text('配置常用表情和输入面板开关'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EmojiSettingsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('网页端设置'),
                    subtitle: const Text('界面偏好、协议与内测状态'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('退出登录'),
                    onTap: _saving ? null : _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('用户协议'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TermsOfServicePage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('隐私政策'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('社区规范'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CommunityGuidelinesPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('举报说明'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReportGuidelinesPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: <Widget>[
                  Text(
                    '西电知行 v${AppConfig.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '校园社区内测项目 · 非西电官方应用',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHero(UserProfile profile) {
    final String backgroundImageUrl = AppConfig.resolveUrl(
      profile.backgroundImageUrl.trim(),
    );
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 144,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              image: backgroundImageUrl.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(backgroundImageUrl),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: _buildAvatar(profile.avatarUrl, profile.nickname),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.nickname,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (profile.bio.trim().isNotEmpty)
                          Text(
                            profile.bio.trim(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.82,
                              ),
                              height: 1.5,
                            ),
                          ),
                        if (profile.gender.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Icon(
                                profile.gender == '男'
                                    ? Icons.male
                                    : Icons.female,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                profile.gender.trim(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.58,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '学号：${profile.studentId.isEmpty ? '未设置' : profile.studentId}',
                        ),
                        Text(
                          '邮箱：${profile.email.isEmpty ? '-' : profile.email}',
                        ),
                        Text(
                          '认证状态：${profile.verified ? '已通过' : '未认证'}（${profile.verifiedAt}）',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, String nickname) {
    final String resolved = AppConfig.resolveUrl(url);
    final String trimmed = nickname.trim();
    final String label = trimmed.isEmpty ? '匿' : trimmed.substring(0, 1);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(label),
          ),
        ),
      );
    }
    return CircleAvatar(radius: 30, child: Text(label));
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final UserProfile profile = await AppRepositories.users.fetchProfile();
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '资料加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadBackgroundImage() async {
    final UserProfile? current = _profile;
    if (current == null) {
      _toast('个人资料尚未加载，无法上传背景图');
      return;
    }
    setState(() {
      _saving = true;
    });

    try {
      final List<PickedImageData> selected = await pickImageFiles(
        multiple: false,
      );
      if (!mounted || selected.isEmpty) {
        return;
      }
      final PickedImageData image = selected.first;
      final String backgroundUrl = await AppRepositories.users
          .uploadBackgroundImage(
            fileName: image.fileName,
            contentType: image.contentType,
            dataBase64: image.dataBase64,
          );
      if (!mounted) {
        return;
      }
      if (backgroundUrl.trim().isNotEmpty) {
        _backgroundUrlController.text = backgroundUrl.trim();
      }
      setState(() {
        _profile = current.copyWith(
          backgroundImageUrl: _backgroundUrlController.text.trim(),
        );
      });
      _toast('背景图上传成功');
    } catch (error) {
      _toast('背景图上传失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final UserProfile? current = _profile;
    if (current == null) {
      _toast('个人资料尚未加载，无法上传头像');
      return;
    }
    setState(() {
      _saving = true;
    });

    try {
      final List<PickedImageData> selected = await pickImageFiles(
        multiple: false,
      );
      if (!mounted || selected.isEmpty) {
        return;
      }
      final PickedImageData image = selected.first;
      final String avatarUrl = await AppRepositories.users.uploadAvatar(
        fileName: image.fileName,
        contentType: image.contentType,
        dataBase64: image.dataBase64,
      );
      if (!mounted) {
        return;
      }
      if (avatarUrl.trim().isNotEmpty) {
        _avatarUrlController.text = avatarUrl.trim();
      }
      setState(() {
        _profile = current.copyWith(
          avatarUrl: _avatarUrlController.text.trim(),
        );
      });
      _toast('头像上传成功');
    } catch (error) {
      _toast('头像上传失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final UserProfile? current = _profile;
    if (current == null) {
      _toast('个人资料尚未加载，无法保存');
      return;
    }
    final String nickname = _nicknameController.text.trim();
    final String avatarUrl = _avatarUrlController.text.trim();
    final String bio = _bioController.text.trim();
    final String backgroundImageUrl = _backgroundUrlController.text.trim();
    final String nextNickname = nickname.isEmpty
        ? (_profile?.nickname ?? '')
        : nickname;

    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.updateProfile(
        nickname: nextNickname,
        avatarUrl: avatarUrl,
        bio: bio,
        backgroundImageUrl: backgroundImageUrl,
        gender: _gender,
      );
      final UserProfile nextProfile = current.copyWith(
        nickname: nextNickname,
        avatarUrl: avatarUrl,
        bio: bio,
        backgroundImageUrl: backgroundImageUrl,
        gender: _gender,
      );
      AuthStore.instance.setCurrentUser(nextProfile);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = nextProfile;
      });
      _toast('资料已更新');
    } catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    final UserProfile? current = _profile;
    if (current == null) {
      _toast('个人资料尚未加载，无法保存隐私设置');
      return;
    }
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.updatePrivacy(
        allowStrangerDm: allowStrangerDm,
        showContactable: showContactable,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = current.copyWith(
          allowStrangerDm: allowStrangerDm,
          showContactable: showContactable,
        );
      });
      _toast('隐私设置已更新');
    } catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _promptAccountCancellationRequest() async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提交注销申请'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '申请说明（可选）',
              hintText: '例如：不再使用、信息更换、测试账号清理等',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确认提交'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null) {
      return;
    }
    await _submitAccountCancellationRequest(reason: reason);
  }

  Future<void> _submitAccountCancellationRequest({String? reason}) async {
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.users.submitAccountCancellationRequest(
        reason: reason,
      );
      await _loadProfile();
      if (!mounted) {
        return;
      }
      _toast('注销申请已提交，等待管理员审核');
    } catch (error) {
      _toast('提交失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _promptLevelUpgradeRequest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('申请成为一级用户'),
          content: const Text('确认提交一级用户申请吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认提交'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await AppRepositories.users.submitLevelUpgradeRequest();
      await _loadProfile();
      if (!mounted) {
        return;
      }
      _toast('一级用户申请已提交');
    } catch (error) {
      _toast('提交失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _accountCancellationSubtitle(
    AccountCancellationRequestSummary request,
  ) {
    final StringBuffer text = StringBuffer();
    text.write('${request.statusLabel} · ${request.createdAt}');
    if (request.reviewNote.trim().isNotEmpty) {
      text.write(' · ${request.reviewNote.trim()}');
    }
    return text.toString();
  }

  String _levelUpgradeSubtitle(UserLevelRequestSummary request) {
    final StringBuffer text = StringBuffer();
    text.write('${request.statusLabel} · ${request.createdAt}');
    if (request.adminNote.trim().isNotEmpty) {
      text.write(' · ${request.adminNote.trim()}');
    }
    return text.toString();
  }

  Future<void> _logout() async {
    setState(() {
      _saving = true;
    });

    try {
      await AppRepositories.auth.logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _toast('退出失败：$error');
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
