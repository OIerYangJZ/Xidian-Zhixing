import 'package:flutter/material.dart';

import '../../core/l10n/ui_text.dart';
import '../../design_system/design_system.dart';
import '../../models/user_profile.dart';
import '../../repositories/app_repositories.dart';

/// 通知偏好: which of the eight notification types are sent. Each switch
/// saves at once and rolls back if the save fails.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  UserProfile? _profile;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final UserProfile profile = await AppRepositories.users.fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _save(UserProfile next) async {
    final UserProfile? previous = _profile;
    setState(() {
      _profile = next;
      _saving = true;
    });
    try {
      await AppRepositories.users.updateNotificationPreferences(
        notifyComment: next.notifyComment,
        notifyReply: next.notifyReply,
        notifyLike: next.notifyLike,
        notifyFavorite: next.notifyFavorite,
        notifyRepost: next.notifyRepost,
        notifyMention: next.notifyMention,
        notifyReportResult: next.notifyReportResult,
        notifySystem: next.notifySystem,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _profile = previous);
      zxShowToast(
        context,
        uiText(context, zh: '保存失败：$error', en: 'Save failed: $error'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    final ZxTokens t = ZxTokens.of(context);
    final UserProfile? p = _profile;

    Widget row({
      required Key key,
      required IconData icon,
      required Color hue,
      required String title,
      required String subtitle,
      required bool value,
      required UserProfile Function(bool) apply,
    }) {
      return ZxListItem(
        icon: icon,
        iconColor: hue,
        title: title,
        subtitle: subtitle,
        trailing: Switch(
          key: key,
          value: value,
          onChanged: _saving ? null : (bool v) => _save(apply(v)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(text('通知偏好', 'Notification preferences'))),
      body: ZxPaper(
        child: p == null
            ? (_error == null
                  ? const Center(child: CircularProgressIndicator())
                  : ZxStatePanel(
                      icon: Icons.error_outline_rounded,
                      error: true,
                      title: text('加载失败', 'Could not load'),
                      message: _error,
                      actionLabel: text('重试', 'Retry'),
                      onAction: _load,
                    ))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ZxListSection(
                            title: text('互动', 'Interactions'),
                            children: <Widget>[
                              row(
                                key: const Key('notify-comment'),
                                icon: Icons.chat_bubble_outline_rounded,
                                hue: t.info,
                                title: text('评论', 'Comments'),
                                subtitle: text(
                                  '有人评论你的帖子',
                                  'Someone comments on your post',
                                ),
                                value: p.notifyComment,
                                apply: (bool v) => p.copyWith(notifyComment: v),
                              ),
                              row(
                                key: const Key('notify-reply'),
                                icon: Icons.reply_rounded,
                                hue: t.primary,
                                title: text('回复', 'Replies'),
                                subtitle: text(
                                  '有人回复你的评论',
                                  'Someone replies to your comment',
                                ),
                                value: p.notifyReply,
                                apply: (bool v) => p.copyWith(notifyReply: v),
                              ),
                              row(
                                key: const Key('notify-like'),
                                icon: Icons.thumb_up_outlined,
                                hue: t.danger,
                                title: text('点赞', 'Likes'),
                                subtitle: text(
                                  '有人喜欢你的帖子或评论',
                                  'Someone likes your post or comment',
                                ),
                                value: p.notifyLike,
                                apply: (bool v) => p.copyWith(notifyLike: v),
                              ),
                              row(
                                key: const Key('notify-favorite'),
                                icon: Icons.star_outline_rounded,
                                hue: t.accentInk,
                                title: text('收藏', 'Saves'),
                                subtitle: text(
                                  '有人收藏你的帖子',
                                  'Someone saves your post',
                                ),
                                value: p.notifyFavorite,
                                apply: (bool v) =>
                                    p.copyWith(notifyFavorite: v),
                              ),
                              row(
                                key: const Key('notify-repost'),
                                icon: Icons.repeat_rounded,
                                hue: t.success,
                                title: text('转发', 'Reposts'),
                                subtitle: text(
                                  '有人转发你的帖子',
                                  'Someone reposts your post',
                                ),
                                value: p.notifyRepost,
                                apply: (bool v) => p.copyWith(notifyRepost: v),
                              ),
                              row(
                                key: const Key('notify-mention'),
                                icon: Icons.alternate_email_rounded,
                                hue: t.primary,
                                title: text('@我', 'Mentions'),
                                subtitle: text(
                                  '有人在帖子或评论中提到你',
                                  'Someone mentions you in a post or comment',
                                ),
                                value: p.notifyMention,
                                apply: (bool v) => p.copyWith(notifyMention: v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          ZxListSection(
                            title: text('社区', 'Community'),
                            children: <Widget>[
                              row(
                                key: const Key('notify-report-result'),
                                icon: Icons.flag_outlined,
                                hue: t.warning,
                                title: text('举报结果', 'Report results'),
                                subtitle: text(
                                  '你的举报处理完成',
                                  'Your report has been handled',
                                ),
                                value: p.notifyReportResult,
                                apply: (bool v) =>
                                    p.copyWith(notifyReportResult: v),
                              ),
                              row(
                                key: const Key('notify-system'),
                                icon: Icons.campaign_outlined,
                                hue: t.text2,
                                title: text('系统', 'System'),
                                subtitle: text(
                                  '公告与账号相关通知',
                                  'Announcements and account notices',
                                ),
                                value: p.notifySystem,
                                apply: (bool v) => p.copyWith(notifySystem: v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
