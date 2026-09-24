import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';

enum _Tone { accent, seal, info, success, warning, danger, neutral }

/// Small label for post and account markers (§06 徽标与未读). Pinned uses the
/// accent, anonymous the seal, states their semantic color on a soft fill.
class ZxBadge extends StatelessWidget {
  const ZxBadge._(
    this.label,
    this._tone, {
    super.key,
    this.icon,
    this.dotColor,
  });

  /// 置顶
  const ZxBadge.pinned(String label, {Key? key})
    : this._(label, _Tone.accent, key: key, icon: Icons.push_pin_outlined);

  /// 匿名
  const ZxBadge.anonymous(String label, {Key? key})
    : this._(label, _Tone.seal, key: key);

  /// 洞主 — the post's author inside its own comments.
  const ZxBadge.author(String label, {Key? key})
    : this._(label, _Tone.seal, key: key);

  /// Channel name with its color dot.
  const ZxBadge.channel(String label, {required Color color, Key? key})
    : this._(label, _Tone.neutral, key: key, dotColor: color);

  /// 进行中
  const ZxBadge.inProgress(String label, {Key? key})
    : this._(label, _Tone.info, key: key, icon: Icons.timelapse_rounded);

  /// 已解决
  const ZxBadge.resolved(String label, {Key? key})
    : this._(label, _Tone.success, key: key, icon: Icons.check_rounded);

  /// 已结束
  const ZxBadge.closed(String label, {Key? key})
    : this._(
        label,
        _Tone.neutral,
        key: key,
        icon: Icons.do_not_disturb_on_outlined,
      );

  /// 仅自己可见
  const ZxBadge.private(String label, {Key? key})
    : this._(label, _Tone.neutral, key: key, icon: Icons.lock_outline_rounded);

  /// 待审核
  const ZxBadge.pendingReview(String label, {Key? key})
    : this._(
        label,
        _Tone.warning,
        key: key,
        icon: Icons.hourglass_empty_rounded,
      );

  /// 未通过审核
  const ZxBadge.rejected(String label, {Key? key})
    : this._(label, _Tone.danger, key: key, icon: Icons.block_rounded);

  /// 已删除
  const ZxBadge.deleted(String label, {Key? key})
    : this._(
        label,
        _Tone.neutral,
        key: key,
        icon: Icons.delete_outline_rounded,
      );

  /// 已屏蔽 / 对方已屏蔽
  const ZxBadge.blocked(String label, {Key? key})
    : this._(label, _Tone.danger, key: key);

  /// 已认证
  const ZxBadge.verified(String label, {Key? key})
    : this._(label, _Tone.success, key: key, icon: Icons.verified_outlined);

  /// Account level, e.g. Lv.2.
  const ZxBadge.level(String label, {Key? key})
    : this._(label, _Tone.accent, key: key);

  final String label;
  final _Tone _tone;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final (Color fg, Color bg) = switch (_tone) {
      _Tone.accent => (t.accentInk, t.accentSoft),
      _Tone.seal => (t.seal, t.sealSoft),
      _Tone.info => (t.info, t.infoSoft),
      _Tone.success => (t.success, t.successSoft),
      _Tone.warning => (t.warning, t.warningSoft),
      _Tone.danger => (t.danger, t.dangerSoft),
      _Tone.neutral => (t.text2, t.bgSunk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: ZxRadius.badgeAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (dotColor != null) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label, style: ZxType.micro.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Unread count: danger dot with a number, capped at 99+.
class ZxCountBadge extends StatelessWidget {
  const ZxCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final ZxTokens t = ZxTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: t.danger,
        borderRadius: ZxRadius.pillAll,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: ZxType.micro.copyWith(color: t.onDanger, height: 1),
      ),
    );
  }
}
