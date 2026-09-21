import 'package:flutter/material.dart';
import '../common/feature_section.dart';

import '../../core/widgets/app_surfaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_store.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/state/app_providers.dart';
import '../../repositories/appeal_repository.dart';

/// Where a banned session lands. The account is signed in, but the server
/// refuses everything except this screen's two endpoints, so there is no shell
/// to show and no point offering navigation.
class BannedAccountPage extends ConsumerStatefulWidget {
  const BannedAccountPage({super.key});

  @override
  ConsumerState<BannedAccountPage> createState() => _BannedAccountPageState();
}

class _BannedAccountPageState extends ConsumerState<BannedAccountPage> {
  final TextEditingController _content = TextEditingController();
  AppealState? _state;
  bool _loading = true;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final AppealState state = await ref
          .read(appealRepositoryProvider)
          .fetchLatest();
      if (!mounted) return;
      // An approved appeal means the ban is already lifted server side; drop
      // the local flag so the next build routes into the app.
      if (!state.banned) {
        AuthStore.instance.setBanned(false);
      }
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final AppealState? state = _state;
    if (state == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await ref
          .read(appealRepositoryProvider)
          .submitUnbanAppeal(
            email: AuthStore.instance.currentUser?.email ?? '',
            content: _content.text,
          );
      _content.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _submitting = false;
      });
      return;
    }
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).clearLocalAuth();
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text('账号已被封禁', 'Account suspended')),
        actions: <Widget>[
          TextButton(
            onPressed: _signOut,
            child: Text(text('退出登录', 'Sign out')),
          ),
        ],
      ),
      body: AppPageFrame(
        maxWidth: 720,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildBody(context, theme, text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    String Function(String, String) text,
  ) {
    final AppealState? state = _state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FeatureSection(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.block, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text('该账号目前被封禁', 'This account is currently suspended'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  text(
                    '封禁期间无法发帖、评论、私信或使用助手。如果你认为这是误判，可在下方提交解封申诉，'
                        '管理员会逐条审核。',
                    'While suspended you cannot post, comment, message or use the '
                        'assistant. If you believe this is a mistake, submit an '
                        'appeal below and an administrator will review it.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _Banner(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            child: Text(_error),
          ),
        ],
        if (state != null) ...<Widget>[
          const SizedBox(height: 16),
          ..._buildAppealSection(context, theme, text, state),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: Text(text('刷新状态', 'Refresh status')),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppealSection(
    BuildContext context,
    ThemeData theme,
    String Function(String, String) text,
    AppealState state,
  ) {
    if (state.mustUseEmail) {
      return <Widget>[
        _Banner(
          icon: Icons.mark_email_unread_outlined,
          color: theme.colorScheme.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                text('申诉未通过', 'Appeal was not approved'),
                style: theme.textTheme.titleSmall,
              ),
              if (state.adminNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(text('管理员说明：', 'Administrator note: ') + state.adminNote),
              ],
              const SizedBox(height: 10),
              Text(
                text(
                  '站内申诉渠道已用尽。如仍有异议，请使用校园邮箱发送邮件说明情况：',
                  'The in-app route is exhausted. If you still disagree, write '
                      'from your campus mailbox to:',
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                state.supportEmail,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text(
                  '请从本人校园邮箱发送，便于核对身份。',
                  'Send it from your own campus mailbox so your identity can be '
                      'verified.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ];
    }

    if (state.hasPending) {
      return <Widget>[
        _Banner(
          icon: Icons.hourglass_top,
          color: theme.colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                text('申诉正在审核中', 'Appeal under review'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                text(
                  '每个账号同时只能有一份待处理申诉。审核完成后再次登录即可看到结果。',
                  'One appeal can be pending at a time. Sign in again after the '
                      'review to see the outcome.',
                ),
              ),
              if (state.content.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  text('你提交的说明：', 'What you submitted: '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(state.content),
              ],
            ],
          ),
        ),
      ];
    }

    return <Widget>[
      FeatureSection(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                text('提交解封申诉', 'Submit an unban appeal'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                maxLines: 8,
                minLines: 5,
                maxLength: 4000,
                enabled: !_submitting,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  labelText: text('申诉说明', 'Your explanation'),
                  hintText: text(
                    '说明你认为封禁属于误判的理由，可附上具体帖子或时间。',
                    'Explain why you believe the suspension is a mistake. Cite '
                        'specific posts or times if you can.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(text('提交申诉', 'Submit appeal')),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.child});

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
