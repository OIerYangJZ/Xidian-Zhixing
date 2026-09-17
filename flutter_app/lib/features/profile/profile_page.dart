import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
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
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    if (_loading) {
      return AppStatePanel(
        icon: Icons.person_outline_rounded,
        title: text('正在加载个人资料', 'Loading profile'),
        message: text(
          '正在同步账号、内容和隐私设置。',
          'Syncing account, content, and privacy settings.',
        ),
      );
    }

    final UserProfile? loadedProfile = _profile;
    if (loadedProfile == null) {
      return AppStatePanel(
        icon: Icons.error_outline,
        title: text('个人资料加载失败', 'Could not load profile'),
        message:
            _error ??
            text('个人资料暂时无法显示', 'Your profile is temporarily unavailable.'),
        action: FilledButton.tonalIcon(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh),
          label: Text(text('重试', 'Retry')),
        ),
      );
    }
    final UserProfile profile = loadedProfile;

    final AccountCancellationRequestSummary? cancellationRequest =
        profile.accountCancellationRequest;

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
                  title: text('资料未完全同步', 'Profile not fully synced'),
                  message: _error!,
                  tone: AppMessageTone.error,
                  action: TextButton(
                    onPressed: _saving ? null : _loadProfile,
                    child: Text(text('重试', 'Retry')),
                  ),
                ),
              ),
            _buildProfileHero(profile),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      text('个人信息', 'Personal information'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nicknameController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: text('用户昵称', 'Nickname'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _avatarUrlController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: text('头像 URL', 'Avatar URL'),
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickAndUploadAvatar,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: Text(
                          text('选择图片并上传头像', 'Choose and upload avatar'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioController,
                      enabled: !_saving,
                      maxLines: 2,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: text('个性签名', 'Bio'),
                        hintText: text(
                          '介绍一下自己吧',
                          'Tell others a little about yourself',
                        ),
                        prefixIcon: const Icon(Icons.edit_note_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: text('性别', 'Gender'),
                        prefixIcon: const Icon(Icons.wc_outlined),
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(text('不显示', 'Prefer not to say')),
                        ),
                        DropdownMenuItem<String>(
                          value: '男',
                          child: Text(text('男', 'Male')),
                        ),
                        DropdownMenuItem<String>(
                          value: '女',
                          child: Text(text('女', 'Female')),
                        ),
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
                      decoration: InputDecoration(
                        labelText: text('主页背景图 URL', 'Profile background URL'),
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.wallpaper_outlined),
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
                        label: Text(
                          text('选择图片并上传背景图', 'Choose and upload background'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? text('保存中...', 'Saving...')
                              : text('保存资料', 'Save profile'),
                        ),
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
                    title: Text(text('我的帖子', 'My posts')),
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
                    title: Text(text('我的评论', 'My comments')),
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
                    title: Text(text('我的举报', 'My reports')),
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
                    title: Text(text('我的收藏', 'My favorites')),
                    subtitle: Text(
                      text(
                        '当前收藏帖子：${profile.favoriteCount}',
                        '${profile.favoriteCount} saved posts',
                      ),
                    ),
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
                    title: Text(text('注销账号申请', 'Account deletion request')),
                    subtitle: Text(
                      cancellationRequest == null
                          ? text(
                              '提交后将进入管理员后台审核，通过后账号才会注销',
                              'Your account is deleted only after an administrator approves the request.',
                            )
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
                    title: Text(
                      text('允许陌生人私信', 'Allow messages from strangers'),
                    ),
                    subtitle: Text(
                      text(
                        '关闭后，其他人无法通过你的公开主页或帖子给你发起私信',
                        'When disabled, people cannot message you from your profile or posts.',
                      ),
                    ),
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
                    title: Text(
                      text('显示“可联系”状态', 'Show available-to-contact status'),
                    ),
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
                    title: Text(text('黑名单管理', 'Blocked accounts')),
                    onTap: () => _toast(
                      text(
                        '黑名单管理暂时不可用',
                        'Blocked accounts are temporarily unavailable.',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_emotions_outlined),
                    title: Text(text('表情设置', 'Emoji settings')),
                    subtitle: Text(
                      text(
                        '配置常用表情和输入面板开关',
                        'Configure favorite emoji and the input panel',
                      ),
                    ),
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
                    title: Text(text('网页端设置', 'Web settings')),
                    subtitle: Text(
                      text(
                        '界面偏好与社区规则',
                        'Appearance preferences and community rules',
                      ),
                    ),
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
                    title: Text(text('退出登录', 'Log out')),
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
                    title: Text(text('用户协议', 'Terms of Service')),
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
                    title: Text(text('隐私政策', 'Privacy Policy')),
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
                    title: Text(text('社区规范', 'Community Guidelines')),
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
                    title: Text(text('举报说明', 'Reporting Guidelines')),
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
                    '${text('西电知行', 'Xidian Zhixing')} v${AppConfig.appVersion}',
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
    final Locale locale = Localizations.localeOf(context);
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
                          profile.nicknameFor(locale),
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
                                profile.genderFor(locale).trim(),
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
                          uiText(
                            context,
                            zh: '学号：${profile.studentId.isEmpty ? '未设置' : profile.studentId}',
                            en: 'Student ID: ${profile.studentId.isEmpty ? 'Not set' : profile.studentId}',
                          ),
                        ),
                        Text(
                          uiText(
                            context,
                            zh: '邮箱：${profile.email.isEmpty ? '-' : profile.email}',
                            en: 'Email: ${profile.email.isEmpty ? '-' : profile.email}',
                          ),
                        ),
                        Text(
                          uiText(
                            context,
                            zh: '认证状态：${profile.verified ? '已通过' : '未认证'}（${profile.verifiedAt}）',
                            en: 'Verification: ${profile.verified ? 'Verified' : 'Not verified'} (${profile.verifiedAt})',
                          ),
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
    final String trimmed = localizedAlias(
      Localizations.localeOf(context),
      nickname,
    ).trim();
    final String label = trimmed.isEmpty
        ? uiText(context, zh: '匿', en: 'A')
        : trimmed.substring(0, 1);
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
        _error = uiTextGlobal(
          zh: '资料加载失败：$error',
          en: 'Failed to load profile: $error',
        );
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
      _toast(
        uiTextGlobal(
          zh: '个人资料尚未加载，无法上传背景图',
          en: 'Profile not loaded yet, cannot upload a background image',
        ),
      );
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
      _toast(uiTextGlobal(zh: '背景图上传成功', en: 'Background image uploaded'));
    } catch (error) {
      _toast(
        uiTextGlobal(
          zh: '背景图上传失败：$error',
          en: 'Background upload failed: $error',
        ),
      );
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
      _toast(
        uiTextGlobal(
          zh: '个人资料尚未加载，无法上传头像',
          en: 'Profile not loaded yet, cannot upload an avatar',
        ),
      );
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
      _toast(uiTextGlobal(zh: '头像上传成功', en: 'Avatar uploaded'));
    } catch (error) {
      _toast(
        uiTextGlobal(zh: '头像上传失败：$error', en: 'Avatar upload failed: $error'),
      );
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
      _toast(
        uiTextGlobal(
          zh: '个人资料尚未加载，无法保存',
          en: 'Profile not loaded yet, nothing to save',
        ),
      );
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
      _toast(uiTextGlobal(zh: '资料已更新', en: 'Profile updated'));
    } catch (error) {
      _toast(uiTextGlobal(zh: '保存失败：$error', en: 'Save failed: $error'));
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
      _toast(
        uiTextGlobal(
          zh: '个人资料尚未加载，无法保存隐私设置',
          en: 'Profile not loaded yet, cannot save privacy settings',
        ),
      );
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
      _toast(uiTextGlobal(zh: '隐私设置已更新', en: 'Privacy settings updated'));
    } catch (error) {
      _toast(uiTextGlobal(zh: '保存失败：$error', en: 'Save failed: $error'));
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
          title: Text(
            uiText(context, zh: '提交注销申请', en: 'Submit a deletion request'),
          ),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: uiText(
                context,
                zh: '申请说明（可选）',
                en: 'Reason (optional)',
              ),
              hintText: uiText(
                context,
                zh: '例如：不再使用或信息变更等',
                en: 'For example: no longer used or information changed',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(uiText(context, zh: '取消', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(uiText(context, zh: '确认提交', en: 'Submit')),
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
      _toast(
        uiTextGlobal(
          zh: '注销申请已提交，等待管理员审核',
          en: 'Deletion request submitted, awaiting administrator review',
        ),
      );
    } catch (error) {
      _toast(uiTextGlobal(zh: '提交失败：$error', en: 'Submit failed: $error'));
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
    final Locale locale = Localizations.localeOf(context);
    final StringBuffer text = StringBuffer();
    text.write('${request.statusLabelFor(locale)} · ${request.createdAt}');
    if (request.reviewNote.trim().isNotEmpty) {
      text.write(' · ${request.reviewNote.trim()}');
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
      _toast(uiTextGlobal(zh: '退出失败：$error', en: 'Log out failed: $error'));
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
