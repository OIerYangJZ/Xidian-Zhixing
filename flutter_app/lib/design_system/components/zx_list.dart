import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';

/// Settings-style row (§06 列表项): tinted icon tile, title, optional
/// subtitle, and a trailing value, status, switch or chevron.
class ZxListItem extends StatelessWidget {
  const ZxListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tile hue; defaults to primary. Danger rows always use danger.
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Destructive entries such as 注销账号申请 and 退出登录.
  final bool danger;

  /// Defaults to showing a chevron when the row navigates and has no
  /// trailing widget.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Color hue = danger ? t.danger : (iconColor ?? t.primary);
    final bool chevron = showChevron ?? (onTap != null && trailing == null);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZxRadius.buttonAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.lerp(hue, t.surface, 0.88),
                      borderRadius: ZxRadius.smallButtonAll,
                    ),
                    child: Icon(icon, size: 18, color: hue),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: ZxType.body.copyWith(
                          color: danger ? t.danger : t.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: ZxType.caption.copyWith(color: t.text3),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
                if (chevron)
                  Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group of [ZxListItem]s inside one card, separated by hairlines.
class ZxListSection extends StatelessWidget {
  const ZxListSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title!,
              style: ZxType.caption.copyWith(
                color: t.text3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: ZxRadius.cardAll,
            border: Border.all(color: t.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 12,
                      color: t.line,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
