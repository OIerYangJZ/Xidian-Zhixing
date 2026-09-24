import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';

/// Page background: `--bg` with the paper grain tiled over it. The handoff
/// draws the grain with an SVG turbulence filter, which neither Flutter nor
/// the mini program can render, so it ships as a small texture instead.
class ZxPaper extends StatelessWidget {
  const ZxPaper({super.key, required this.child, this.grain = true});

  final Widget child;

  /// Off for surfaces that scroll large images, where grain reads as noise.
  final bool grain;

  static const AssetImage _grain = AssetImage('assets/design/paper_grain.png');

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        image: grain
            ? const DecorationImage(image: _grain, repeat: ImageRepeat.repeat)
            : null,
      ),
      child: child,
    );
  }
}

/// Frosted bar for app bars, bottom bars and floating layers: blur plus the
/// translucent `--glass` surface, so content shows through while scrolling.
/// Where blur is too costly, pass [blur] false for the same color, opaque
/// enough to stay legible.
class ZxGlass extends StatelessWidget {
  const ZxGlass({
    super.key,
    required this.child,
    this.blur = true,
    this.borderRadius,
    this.border = true,
  });

  final Widget child;
  final bool blur;
  final BorderRadius? borderRadius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: blur ? t.glass : t.surface,
        borderRadius: borderRadius,
        border: border ? Border(bottom: BorderSide(color: t.line)) : null,
      ),
      child: child,
    );
    if (blur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: content,
    );
  }
}

/// Elevation levels (§05): 0 hairline for lists, 1 for cards, 2 for menus,
/// sheets and dialogs.
enum ZxElevation { flat, card, overlay }

/// Rounded surface with the design system's border and shadow.
class ZxCard extends StatelessWidget {
  const ZxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevation = ZxElevation.card,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ZxElevation elevation;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final BorderRadius radius = elevation == ZxElevation.overlay
        ? ZxRadius.sheetAll
        : ZxRadius.cardAll;
    final List<BoxShadow> shadow = switch (elevation) {
      ZxElevation.flat => const <BoxShadow>[],
      ZxElevation.card => t.shadow1,
      ZxElevation.overlay => t.shadow2,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            color ?? (elevation == ZxElevation.overlay ? t.raised : t.surface),
        borderRadius: radius,
        border: Border.all(color: t.line),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The warm wash used behind page headers and empty states.
class ZxHeroWash extends StatelessWidget {
  const ZxHeroWash({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: t.line),
        gradient: LinearGradient(
          // 125° in CSS: from top-left towards bottom-right.
          begin: const Alignment(-0.82, -0.57),
          end: const Alignment(0.82, 0.57),
          colors: t.heroGradient,
          stops: const <double>[0, 0.52, 1],
        ),
      ),
      child: child,
    );
  }
}
