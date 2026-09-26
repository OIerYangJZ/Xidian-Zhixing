import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_store.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/network/api_exception.dart';
import '../../core/state/app_providers.dart';
import '../../core/utils/code_point_limit.dart';
import '../../design_system/design_system.dart';
import '../../repositories/appeal_repository.dart';

String _messageOf(Object error) => switch (error) {
  ApiException(:final String message) => message,
  FormatException(:final String message) => message,
  _ => '$error',
};

/// Where a banned session lands (handoff W9), on the web and on Android. The
/// account is signed in, but the server refuses everything except this
/// screen's endpoints and the profile, so there is no shell to show and no
/// point offering navigation.
class BannedAccountPage extends ConsumerStatefulWidget {
  const BannedAccountPage({super.key, this.onSignedOut});

  /// The web has no router guard and moves to the login page here; on
  /// Android the guard does it when the session clears.
  final VoidCallback? onSignedOut;

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
      // the local flag so the app routes back in.
      if (!state.banned) {
        AuthStore.instance.liftBan();
      }
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageOf(error);
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
      // The appeal is filed under the campus address signed in with; after
      // a restart the profile has not been read yet.
      if (AuthStore.instance.currentUser == null) {
        final profile = await ref.read(userRepositoryProvider).fetchProfile();
        AuthStore.instance.setCurrentUser(profile);
      }
      await ref
          .read(appealRepositoryProvider)
          .submitUnbanAppeal(
            email: AuthStore.instance.currentUser!.email,
            content: _content.text,
          );
      _content.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      // 409: this ban's in-app appeal is used up (or one is pending). The
      // state reloads so the page shows the mailbox route; the reason stays.
      if (error is ApiException && error.statusCode == 409) {
        await _load();
        if (!mounted) return;
      }
      setState(() {
        _error = _messageOf(error);
        _submitting = false;
      });
      return;
    }
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (error) {
      if (mounted) {
        zxShowToast(
          context,
          uiTextGlobal(zh: '退出失败：$error', en: 'Sign-out failed: $error'),
        );
      }
      return;
    }
    widget.onSignedOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    String text(String zh, String en) => uiText(context, zh: zh, en: en);
    final ZxTokens t = ZxTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text('账号已被封禁', 'Account suspended')),
        actions: <Widget>[
          ZxButton(
            key: const Key('banned-sign-out'),
            label: text('退出登录', 'Sign out'),
            icon: Icons.logout_rounded,
            variant: ZxButtonVariant.secondary,
            small: true,
            onPressed: _signOut,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ZxPaper(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _loading && _state == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _notice(t, text),
                        if (_error.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          ZxInlineMessage(
                            key: const Key('banned-error'),
                            message: _error,
                            tone: ZxMessageTone.danger,
                          ),
                        ],
                        if (_state != null) ...<Widget>[
                          const SizedBox(height: 14),
                          _appealSection(t, text, _state!),
                        ],
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton.icon(
                            key: const Key('banned-refresh'),
                            onPressed: _loading ? null : _load,
                            style: TextButton.styleFrom(
                              foregroundColor: t.text2,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(text('刷新状态', 'Refresh status')),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(ZxTokens t, String Function(String, String) text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.dangerSoft,
        borderRadius: ZxRadius.cardAll,
        border: Border.all(color: t.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.danger,
              borderRadius: ZxRadius.buttonAll,
            ),
            child: Icon(Icons.block_rounded, color: t.onDanger, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text(
                '封禁期间不能发帖、评论、私信或使用校园 AI。如认为处理有误，可以提交解封申诉。',
                'While suspended you cannot post, comment, message or use '
                    'Campus AI. If you think this is a mistake, submit an appeal.',
              ),
              style: ZxType.body.copyWith(color: t.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appealSection(
    ZxTokens t,
    String Function(String, String) text,
    AppealState state,
  ) {
    if (state.mustUseEmail) {
      return ZxCard(
        key: const Key('banned-email-only'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              text('申诉未通过', 'Appeal was not approved'),
              style: ZxType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: 6),
            Text(
              <String>[
                if (state.adminNote.isNotEmpty)
                  text('管理员说明：', 'Administrator note: ') + state.adminNote,
                text(
                  '站内申诉次数已用完，请用本人校园邮箱发送至支持邮箱。',
                  'In-app appeals are used up. Write from your own campus '
                      'mailbox to the support address.',
                ),
              ].join(' · '),
              style: ZxType.body.copyWith(color: t.text2),
            ),
            if (state.supportEmail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                decoration: BoxDecoration(
                  color: t.bgSunk,
                  borderRadius: ZxRadius.buttonAll,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SelectableText(
                        state.supportEmail,
                        style: ZxType.label.copyWith(color: t.text),
                      ),
                    ),
                    IconButton(
                      key: const Key('banned-copy-email'),
                      tooltip: text('复制', 'Copy'),
                      icon: Icon(Icons.copy_rounded, size: 16, color: t.text3),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.supportEmail),
                        );
                        if (mounted) {
                          zxShowToast(context, text('已复制', 'Copied'));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (state.hasPending) {
      return Container(
        key: const Key('banned-pending'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.accentSoft,
          borderRadius: ZxRadius.cardAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: 20, color: t.accentInk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text('申诉正在审核中', 'Appeal under review'),
                    style: ZxType.label.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text(
                      '同一时间只能有一份待处理申诉。下方回显你提交的说明。',
                      'Only one appeal can be pending at a time. What you '
                          'submitted is below.',
                    ),
                    style: ZxType.body.copyWith(color: t.text2),
                  ),
                  if (state.content.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: ZxRadius.buttonAll,
                      ),
                      child: SelectableText(
                        state.content,
                        style: ZxType.body.copyWith(color: t.text),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ZxCard(
      key: const Key('banned-appeal-form'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            text('提交解封申诉', 'Submit an unban appeal'),
            style: ZxType.headline.copyWith(fontSize: 20, color: t.text),
          ),
          const SizedBox(height: 12),
          Text(
            text('申诉说明', 'Your explanation'),
            style: ZxType.caption.copyWith(
              color: t.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('banned-appeal-input'),
            controller: _content,
            maxLines: 8,
            minLines: 6,
            maxLength: 4000,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            inputFormatters: <TextInputFormatter>[
              CodePointLimitFormatter(4000),
            ],
            buildCounter: codePointCounter(_content),
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: text(
                '请说明你认为处理有误的原因，以及相关的帖子或时间。',
                'Explain why you think this is a mistake, and cite the posts '
                    'or times involved.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ZxButton(
            key: const Key('banned-appeal-submit'),
            label: text('提交申诉', 'Submit appeal'),
            loading: _submitting,
            expand: true,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
