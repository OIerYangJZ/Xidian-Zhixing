import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';

enum ZxButtonVariant {
  /// The single main action on a screen: gradient fill and primary glow.
  primary,

  /// Neutral action on a sunk background.
  secondary,

  /// Outlined, for actions that sit next to a primary one.
  outline,

  /// Destructive confirmation.
  danger,

  /// Text only.
  ghost,
}

/// Button from the design system (§06). [loading] shows a spinner and blocks
/// taps; a null [onPressed] renders the disabled state.
class ZxButton extends StatelessWidget {
  const ZxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ZxButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ZxButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    // Loading keeps the variant's look (提交中…) and only blocks taps;
    // a null onPressed is the greyed disabled state.
    final bool disabled = onPressed == null;
    final bool tappable = !disabled && !loading;
    final BorderRadius radius = small
        ? ZxRadius.smallButtonAll
        : ZxRadius.buttonAll;

    final (Color fg, Color? bg, Border? border) = switch (variant) {
      ZxButtonVariant.primary => (t.onPrimary, null, null),
      ZxButtonVariant.secondary => (t.text, t.bgSunk, null),
      ZxButtonVariant.outline => (
        t.text,
        t.surface,
        Border.all(color: t.lineStrong),
      ),
      ZxButtonVariant.danger => (t.onDanger, t.danger, null),
      ZxButtonVariant.ghost => (t.primary, null, null),
    };
    final bool glow = variant == ZxButtonVariant.primary && !disabled;

    final BoxDecoration decoration =
        disabled && variant != ZxButtonVariant.ghost
        ? BoxDecoration(color: t.bgSunk, borderRadius: radius)
        : BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: border,
            // Lighter at the top, deeper at the bottom (§03 主色光晕).
            gradient: variant == ZxButtonVariant.primary
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.lerp(t.primary, t.surface, 0.1)!,
                      t.primaryPressed,
                    ],
                  )
                : null,
            boxShadow: glow
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.primaryGlow,
                      blurRadius: 18,
                      spreadRadius: -6,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          );

    final Color labelColor = disabled ? t.text3 : fg;
    final TextStyle style = (small ? ZxType.caption : ZxType.label).copyWith(
      color: labelColor,
      fontWeight: FontWeight.w600,
    );
    final double iconSize = small ? 15 : 17;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: labelColor),
          )
        else if (icon != null)
          Icon(icon, size: iconSize, color: labelColor),
        if (loading || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: tappable,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: tappable ? onPressed : null,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: small ? 32 : ZxSize.minTouchTarget,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 12 : 18),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
