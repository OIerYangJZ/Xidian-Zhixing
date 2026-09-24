import 'package:flutter/material.dart';

import '../../core/auth/auth_store.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/legal/community_guidelines_page.dart';
import '../../features/legal/report_guidelines_page.dart';
import '../auth/login_page.dart';
import 'blocked_accounts_page.dart';
import 'edit_profile_page.dart';
import 'follow_list_page.dart';
import 'notification_preferences_page.dart';
import 'reason_dialog.dart';
import 'settings_page.dart';
import '../me/my_comments_page.dart';
import '../me/my_favorites_page.dart';
import '../me/my_posts_page.dart';
import '../me/my_reports_page.dart';

/// 个人资料与设置 (handoff W6): the profile card with counts, the four
/// content entries, then 账号 / 隐私与通知 / 更多 and 退出登录.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> refreshProfile() => _loadProfile();

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    return Scaffold(
      appBar: AppBar(title: Text(text('个人资料与设置', 'Profile and settings'))),
      body: ZxPaper(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    if (_loading && _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final UserProfile? loadedProfile = _profile;
    if (loadedProfile == null) {
      return ZxStatePanel(
        icon: Icons.error_outline_rounded,
        error: true,
        title: text('个人资料加载失败', 'Could not load profile'),
        message:
            _error ??
            text('个人资料暂时无法显示', 'Your profile is temporarily unavailable.'),
        actionLabel: text('重试', 'Retry'),
        onAction: _loadProfile,
      );
    }
    final UserProfile profile = loadedProfile;
    final ZxTokens t = ZxTokens.of(context);

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ZxInlineMessage(
                        message: _error!,
                        tone: ZxMessageTone.danger,
                        actionLabel: text('重试', 'Retry'),
                        onAction: _saving ? null : _loadProfile,
                      ),
                    ),
                  _ProfileHero(
                    profile: profile,
                    busy: _saving,
                    onEdit: _openEditor,
                    onOpenFollows: (FollowListTab tab) =>
                        _open(FollowListPage(initialTab: tab), reload: true),
                    onOpenPosts: () => _open(const MyPostsPage()),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _QuickEntry(
                        icon: Icons.edit_outlined,
                        hue: t.primary,
                        label: text('我的帖子', 'My posts'),
                        onTap: () => _open(const MyPostsPage()),
                      ),
                      const SizedBox(width: 10),
                      _QuickEntry(
                        icon: Icons.chat_bubble_outline_rounded,
                        hue: t.info,
                        label: text('我的评论', 'My comments'),
                        onTap: () => _open(const MyCommentsPage()),
                      ),
                      const SizedBox(width: 10),
                      _QuickEntry(
                        icon: Icons.star_outline_rounded,
                        hue: t.accentInk,
                        label: text('我的收藏', 'Saved'),
                        count: profile.favoriteCount,
                        onTap: () =>
                            _open(const MyFavoritesPage(), reload: true),
                      ),
                      const SizedBox(width: 10),
                      _QuickEntry(
                        icon: Icons.flag_outlined,
                        hue: t.seal,
                        label: text('我的举报', 'My reports'),
                        onTap: () => _open(const MyReportsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ZxListSection(
                    title: text('账号', 'Account'),
                    children: <Widget>[
                      ZxListItem(
                        icon: Icons.people_outline_rounded,
                        iconColor: t.success,
                        title: text('关注与粉丝', 'Following and followers'),
                        subtitle: text(
                          '查看关注、粉丝、好友列表',
                          'Following, followers and friends',
                        ),
                        onTap: () =>
                            _open(const FollowListPage(), reload: true),
                      ),
                      if (!profile.isLevelOneUser)
                        ZxListItem(
                          key: const Key('profile-level-upgrade'),
                          icon: Icons.verified_user_outlined,
                          iconColor: t.success,
                          title: text('申请成为一级用户', 'Apply for level 1'),
                          subtitle: _levelSubtitle(profile),
                          onTap: _saving || _levelRequestPending(profile)
                              ? null
                              : _promptLevelUpgradeRequest,
                          showChevron: !_levelRequestPending(profile),
                        ),
                      ZxListItem(
                        icon: Icons.error_outline_rounded,
                        danger: true,
                        title: text('注销账号申请', 'Account deletion request'),
                        subtitle: profile.accountCancellationRequest == null
                            ? text(
                                '提交后进入管理员审核，通过后账号才会注销',
                                'Your account is deleted only after an administrator approves the request.',
                              )
                            : _accountCancellationSubtitle(
                                profile.accountCancellationRequest!,
                              ),
                        onTap:
                            _saving ||
                                profile.accountCancellationRequest?.status ==
                                    'pending'
                            ? null
                            : _promptAccountCancellationRequest,
                        showChevron: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ZxListSection(
                    title: text('隐私与通知', 'Privacy and notifications'),
                    children: <Widget>[
                      ZxListItem(
                        icon: Icons.chat_outlined,
                        iconColor: t.info,
                        title: text('允许陌生人私信', 'Allow messages from strangers'),
                        subtitle: text(
                          '关闭后，别人不能从你的主页或帖子发起私信',
                          'When off, people cannot message you from your profile or posts.',
                        ),
                        trailing: Switch(
                          key: const Key('profile-allow-dm'),
                          value: profile.allowStrangerDm,
                          onChanged: _saving
                              ? null
                              : (bool value) => _updatePrivacy(
                                  allowStrangerDm: value,
                                  showContactable: profile.showContactable,
                                ),
                        ),
                      ),
                      ZxListItem(
                        icon: Icons.visibility_outlined,
                        iconColor: t.success,
                        title: text(
                          '显示「可联系」状态',
                          'Show available-to-contact status',
                        ),
                        trailing: Switch(
                          value: profile.showContactable,
                          onChanged: _saving
                              ? null
                              : (bool value) => _updatePrivacy(
                                  allowStrangerDm: profile.allowStrangerDm,
                                  showContactable: value,
                                ),
                        ),
                      ),
                      ZxListItem(
                        icon: Icons.notifications_none_rounded,
                        iconColor: t.accentInk,
                        title: text('通知偏好', 'Notification preferences'),
                        subtitle: text(
                          '评论、回复、点赞、收藏、举报结果、系统',
                          'Comments, replies, likes, saves, reports, system',
                        ),
                        onTap: () => _open(
                          const NotificationPreferencesPage(),
                          reload: true,
                        ),
                      ),
                      ZxListItem(
                        icon: Icons.block_rounded,
                        iconColor: t.text2,
                        title: text('黑名单管理', 'Blocked accounts'),
                        onTap: () => _open(const BlockedAccountsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ZxListSection(
                    title: text('更多', 'More'),
                    children: <Widget>[
                      ZxListItem(
                        icon: Icons.tune_rounded,
                        title: text('设置', 'Settings'),
                        subtitle: text(
                          '语言、配色主题、明暗模式、表情',
                          'Language, color theme, appearance, emoji',
                        ),
                        onTap: () => _open(const SettingsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Material(
                    color: t.dangerSoft,
                    borderRadius: ZxRadius.buttonAll,
                    child: InkWell(
                      key: const Key('profile-logout'),
                      borderRadius: ZxRadius.buttonAll,
                      onTap: _saving ? null : _logout,
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: t.danger,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              text('退出登录', 'Log out'),
                              style: ZxType.label.copyWith(color: t.danger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: <Widget>[
                      _FooterLink(
                        label: text('用户协议', 'Terms'),
                        onTap: () => _open(const TermsOfServicePage()),
                      ),
                      _FooterLink(
                        label: text('隐私政策', 'Privacy'),
                        onTap: () => _open(const PrivacyPolicyPage()),
                      ),
                      _FooterLink(
                        label: text('社区规范', 'Guidelines'),
                        onTap: () => _open(const CommunityGuidelinesPage()),
                      ),
                      _FooterLink(
                        label: text('举报说明', 'Reporting'),
                        onTap: () => _open(const ReportGuidelinesPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${text('西电知行', 'Xidian Zhixing')} v${AppConfig.appVersion}',
                    textAlign: TextAlign.center,
                    style: ZxType.caption.copyWith(color: t.text3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Widget page, {bool reload = false}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (reload && mounted) await _loadProfile();
  }

  Future<void> _openEditor() async {
    final UserProfile? current = _profile;
    if (current == null) return;
    final UserProfile? updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => EditProfilePage(profile: current),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  bool _levelRequestPending(UserProfile profile) =>
      profile.levelUpgradeRequest?.status.trim().toLowerCase() == 'pending';

  String _levelSubtitle(UserProfile profile) {
    final Locale locale = Localizations.localeOf(context);
    final UserLevelRequestSummary? request = profile.levelUpgradeRequest;
    if (request != null && _levelRequestPending(profile)) {
      return uiText(
        context,
        zh: '已提交申请，等待管理员审核',
        en: 'Request submitted, awaiting review',
      );
    }
    final String current = uiText(
      context,
      zh: '当前为${profile.userLevelLabelFor(locale)}，可申请升级',
      en: 'You are ${profile.userLevelLabelFor(locale)}; you can apply to upgrade',
    );
    if (request == null) return current;
    final String note = request.adminNote.trim();
    return '${request.statusLabelFor(locale)}${note.isEmpty ? '' : ' · $note'} · $current';
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

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    final UserProfile? current = _profile;
    if (current == null) {
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

  Future<void> _promptLevelUpgradeRequest() async {
    final String? reason = await showReasonDialog(
      context,
      title: uiText(context, zh: '申请成为一级用户', en: 'Apply for level 1'),
      message: uiText(
        context,
        zh: '一级用户可以申请置顶帖子。提交后由管理员审核。',
        en: 'Level 1 users can request pinned posts. An administrator reviews the request.',
      ),
      hint: uiText(
        context,
        zh: '例如：社团负责人，需要发布活动通知',
        en: 'For example: I run a club and post event notices',
      ),
      confirmLabel: uiText(context, zh: '提交申请', en: 'Submit'),
    );
    if (reason == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppRepositories.users.submitLevelUpgradeRequest(reason: reason);
      await _loadProfile();
      _toast(
        uiTextGlobal(
          zh: '申请已提交，等待管理员审核',
          en: 'Request submitted, awaiting review',
        ),
      );
    } catch (error) {
      _toast(uiTextGlobal(zh: '提交失败：$error', en: 'Submit failed: $error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _promptAccountCancellationRequest() async {
    final String? reason = await showReasonDialog(
      context,
      title: uiText(context, zh: '提交注销申请', en: 'Submit a deletion request'),
      message: uiText(
        context,
        zh: '管理员审核通过后，账号才会注销。',
        en: 'Your account is deleted only after an administrator approves.',
      ),
      hint: uiText(
        context,
        zh: '例如：不再使用或信息变更等',
        en: 'For example: no longer used or information changed',
      ),
      confirmLabel: uiText(context, zh: '确认提交', en: 'Submit'),
      danger: true,
    );
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
    zxShowToast(context, message);
  }
}

/// 学号 21****0137: the middle hidden on screen.
String maskStudentId(String id) {
  final String value = id.trim();
  if (value.length <= 6) return value;
  return '${value.substring(0, 2)}****${value.substring(value.length - 4)}';
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.busy,
    required this.onEdit,
    required this.onOpenFollows,
    required this.onOpenPosts,
  });

  final UserProfile profile;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<FollowListTab> onOpenFollows;
  final VoidCallback onOpenPosts;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String background = AppConfig.resolveUrl(
      profile.backgroundImageUrl.trim(),
    );
    final String nickname = profile.nicknameFor(locale);
    final String studentId = maskStudentId(profile.studentId);
    final List<String> meta = <String>[
      if (studentId.isNotEmpty)
        uiText(context, zh: '学号 $studentId', en: 'ID $studentId'),
      if (profile.gender.trim().isNotEmpty) profile.genderFor(locale).trim(),
      if (profile.email.trim().isNotEmpty) profile.email.trim(),
    ];

    return ZxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ZxRadius.card),
            ),
            child: SizedBox(
              height: 132,
              child: background.isEmpty
                  ? ZxHeroWash(child: const SizedBox.expand())
                  : Image.network(
                      background,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ZxHeroWash(child: const SizedBox.expand()),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.surface, width: 4),
                        ),
                        child: ZxAvatar(
                          name: nickname,
                          imageUrl: profile.avatarUrl,
                          size: 76,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ZxButton(
                        key: const Key('profile-edit'),
                        label: uiText(context, zh: '编辑资料', en: 'Edit profile'),
                        icon: Icons.edit_outlined,
                        variant: ZxButtonVariant.secondary,
                        small: true,
                        onPressed: busy ? null : onEdit,
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            nickname,
                            style: ZxType.headline.copyWith(color: t.text),
                          ),
                          if (profile.verified)
                            ZxBadge.verified(
                              uiText(context, zh: '已认证', en: 'Verified'),
                            ),
                          ZxBadge.level(
                            'Lv.${profile.isLevelOneUser ? 1 : profile.userLevel}',
                          ),
                        ],
                      ),
                      if (profile.bio.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          profile.bio.trim(),
                          style: ZxType.body.copyWith(color: t.text2),
                        ),
                      ],
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          meta.join('  ·  '),
                          style: ZxType.caption.copyWith(color: t.text3),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: t.bgSunk,
                    borderRadius: ZxRadius.buttonAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      _Stat(
                        count: profile.postCount,
                        label: uiText(context, zh: '帖子', en: 'Posts'),
                        onTap: onOpenPosts,
                      ),
                      _Stat(
                        count: profile.followingCount,
                        label: uiText(context, zh: '关注', en: 'Following'),
                        onTap: () => onOpenFollows(FollowListTab.following),
                      ),
                      _Stat(
                        count: profile.followerCount,
                        label: uiText(context, zh: '粉丝', en: 'Followers'),
                        onTap: () => onOpenFollows(FollowListTab.followers),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label, required this.onTap});

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: ZxRadius.buttonAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: <Widget>[
              Text('$count', style: ZxType.title.copyWith(color: t.text)),
              Text(label, style: ZxType.caption.copyWith(color: t.text3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.icon,
    required this.hue,
    required this.label,
    required this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final Color hue;
  final String label;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Expanded(
      child: ZxCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color.lerp(hue, t.surface, 0.86),
                borderRadius: ZxRadius.buttonAll,
              ),
              child: Icon(icon, size: 20, color: hue),
            ),
            const SizedBox(height: 8),
            Text(
              count > 0 ? '$label $count' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZxType.caption.copyWith(
                color: t.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: ZxTokens.of(context).text2,
      ),
      child: Text(label, style: ZxType.caption),
    );
  }
}
