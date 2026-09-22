import 'package:flutter/material.dart';
import '../common/feature_section.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/media/image_picker_adapter.dart';
import '../../core/media/picked_image_data.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/shared_colors.dart';
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
  const ProfilePage({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

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
  bool _editing = false;
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

    if (AppBreakpoints.isDesktop(context)) {
      return _buildReferenceDesktopProfile(context, profile);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
            OutlinedButton.icon(
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined),
              label: Text(
                _editing
                    ? text('关闭编辑', 'Close editor')
                    : text('编辑个人资料', 'Edit profile'),
              ),
            ),
            if (_editing)
              FeatureSection(
                padding: EdgeInsets.zero,
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
                          labelText: text(
                            '主页背景图 URL',
                            'Profile background URL',
                          ),
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
            FeatureSection(
              padding: EdgeInsets.zero,
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
                ],
              ),
            ),
            const SizedBox(height: 6),
            FeatureSection(
              padding: EdgeInsets.zero,
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
                    onTap: () => _openBlockedAccounts(),
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
                      if (widget.onOpenSettings != null) {
                        widget.onOpenSettings!();
                        return;
                      }
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
            FeatureSection(
              padding: EdgeInsets.zero,
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

  Widget _buildReferenceDesktopProfile(
    BuildContext context,
    UserProfile profile,
  ) {
    final double scale = AppLayout.shellScale(MediaQuery.sizeOf(context).width);
    final EditorialColors colors = EditorialColors.of(context);
    final String nickname = profile.nickname.trim().isEmpty
        ? 'Zavier'
        : profile.nickname.trim();
    final String handle = nickname.toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final String bio = profile.bio.trim().isEmpty
        ? 'Still alive'
        : profile.bio.trim();
    final String avatarUrl = profile.avatarUrl.trim();

    Widget avatar(double size) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: colors.primarySubtle,
        backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
        child: avatarUrl.isEmpty
            ? Text(
                nickname.characters.first,
                style: TextStyle(fontSize: size * .38, color: colors.ink),
              )
            : null,
      );
    }

    Text small(String value, {FontWeight weight = FontWeight.w400}) => Text(
      value,
      style: TextStyle(
        fontSize: 18 * scale,
        height: 1.25,
        fontWeight: weight,
        color: colors.ink,
      ),
    );

    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.only(top: 100 * scale),
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(34 * scale),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      33 * scale,
                      31 * scale,
                      33 * scale,
                      18 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 23 * scale),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      nickname,
                                      style: TextStyle(
                                        fontSize: 24 * scale,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                        color: colors.ink,
                                      ),
                                    ),
                                    SizedBox(height: 7 * scale),
                                    small(handle),
                                    SizedBox(height: 54 * scale),
                                    small(bio),
                                    SizedBox(height: 39 * scale),
                                    Row(
                                      children: <Widget>[
                                        for (final String tag in <String>[
                                          'workout',
                                          'beijing',
                                          '+',
                                        ])
                                          Padding(
                                            padding: EdgeInsets.only(
                                              right: 8 * scale,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14 * scale,
                                                vertical: 7 * scale,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colors.primarySubtle,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      18 * scale,
                                                    ),
                                              ),
                                              child: small(tag),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 46 * scale),
                                    small('🌐 7 个关注者'),
                                  ],
                                ),
                              ),
                            ),
                            avatar(112 * scale),
                          ],
                        ),
                        SizedBox(height: 43 * scale),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _editing = !_editing),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size.fromHeight(52 * scale),
                                  side: BorderSide(color: colors.line),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      14 * scale,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  '编辑资料',
                                  style: TextStyle(
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size.fromHeight(52 * scale),
                                  side: BorderSide(color: colors.line),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      14 * scale,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  '查看数据',
                                  style: TextStyle(
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54 * scale,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        for (final String label in <String>[
                          '帖子',
                          '回复',
                          '媒体',
                          '转发',
                        ])
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: label == '帖子'
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: colors.ink,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _ReferenceProfileComposer(scale: scale, colors: colors),
                  _ReferenceProfilePost(
                    scale: scale,
                    colors: colors,
                    avatar: avatar,
                    author: handle,
                    text: '你好',
                    date: '09/10/26',
                  ),
                  _ReferenceProfilePost(
                    scale: scale,
                    colors: colors,
                    avatar: avatar,
                    author: handle,
                    text: '欢迎来到我的主页',
                    date: '09/04/26',
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 8 * scale,
          right: 8 * scale,
          child: PopupMenuButton<String>(
            tooltip: '更多',
            icon: Icon(Icons.more_horiz, size: 28 * scale),
            onSelected: (String value) {
              if (value == 'settings') widget.onOpenSettings?.call();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'settings', child: Text('设置')),
            ],
          ),
        ),
      ],
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
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (backgroundImageUrl.isNotEmpty)
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
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildAvatar(profile.avatarUrl, profile.nickname),
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

  Future<void> _openBlockedAccounts() async {
    List<Map<String, dynamic>> blocks = <Map<String, dynamic>>[];
    try {
      blocks = await AppRepositories.users.fetchBlocks();
    } catch (error) {
      _toast(
        uiTextGlobal(
          zh: '黑名单加载失败：$error',
          en: 'Could not load blocked accounts: $error',
        ),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: Text(
                uiText(sheetContext, zh: '黑名单管理', en: 'Blocked accounts'),
              ),
            ),
            if (blocks.isEmpty)
              ListTile(
                title: Text(
                  uiText(sheetContext, zh: '暂无屏蔽用户', en: 'No blocked accounts'),
                ),
              ),
            for (final Map<String, dynamic> item in blocks)
              ListTile(
                leading: AppSealMark(size: 36),
                title: Text((item['nickname'] ?? '西电同学').toString()),
                trailing: TextButton(
                  onPressed: () async {
                    await AppRepositories.users.unblockUser(
                      (item['id'] ?? '').toString(),
                    );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    _openBlockedAccounts();
                  },
                  child: Text(uiText(sheetContext, zh: '解除屏蔽', en: 'Unblock')),
                ),
              ),
          ],
        ),
      ),
    );
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

class _ReferenceProfileComposer extends StatelessWidget {
  const _ReferenceProfileComposer({required this.scale, required this.colors});

  final double scale;
  final EditorialColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105 * scale,
      padding: EdgeInsets.symmetric(horizontal: 33 * scale),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line),
          bottom: BorderSide(color: colors.line),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 25 * scale,
            backgroundColor: colors.primarySubtle,
            child: Text('匿', style: TextStyle(fontSize: 20 * scale)),
          ),
          SizedBox(width: 17 * scale),
          Expanded(
            child: Text(
              '有什么新鲜事？',
              style: TextStyle(fontSize: 22 * scale, color: colors.mutedInk),
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: Size(92 * scale, 54 * scale),
              padding: EdgeInsets.zero,
              side: BorderSide(color: colors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15 * scale),
              ),
            ),
            child: Text(
              '发帖',
              style: TextStyle(
                fontSize: 21 * scale,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceProfilePost extends StatelessWidget {
  const _ReferenceProfilePost({
    required this.scale,
    required this.colors,
    required this.avatar,
    required this.author,
    required this.text,
    required this.date,
  });

  final double scale;
  final EditorialColors colors;
  final Widget Function(double size) avatar;
  final String author;
  final String text;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        33 * scale,
        22 * scale,
        33 * scale,
        23 * scale,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          avatar(50 * scale),
          SizedBox(width: 17 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: colors.mutedInk,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '···',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 22 * scale,
                        color: colors.mutedInk,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * scale),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 22 * scale,
                    height: 1.32,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: 20 * scale),
                Row(
                  children: <Widget>[
                    for (final IconData icon in <IconData>[
                      Icons.favorite_border,
                      Icons.chat_bubble_outline,
                      Icons.repeat,
                      Icons.send_outlined,
                    ])
                      Padding(
                        padding: EdgeInsets.only(right: 30 * scale),
                        child: Icon(
                          icon,
                          size: 28 * scale,
                          color: colors.mutedInk,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
