import 'package:flutter/material.dart';

import '../zx_metrics.dart';
import '../zx_tokens.dart';

/// Avatar (§06 头像). Always a rounded square: the product uses no circles.
/// A real-name account shows its photo, or its first character on a light
/// tint of a stable channel hue, with a ~24% corner. An anonymous identity is
/// the seal: solid seal color, inner white line like ink paste, ~15% corner.
/// The fill tells them apart. The seal never links to a profile, so [onTap]
/// is ignored for it.
class ZxAvatar extends StatelessWidget {
  const ZxAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.onTap,
  }) : anonymous = false;

  const ZxAvatar.anonymous({super.key, required this.name, this.size = 40})
    : anonymous = true,
      imageUrl = null,
      onTap = null;

  final String name;
  final String? imageUrl;
  final double size;
  final bool anonymous;
  final VoidCallback? onTap;

  String get _initial {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final Widget avatar = anonymous ? _seal(t) : _realName(t);
    return Semantics(
      label: name,
      image: true,
      button: !anonymous && onTap != null,
      child: !anonymous && onTap != null
          ? GestureDetector(onTap: onTap, child: avatar)
          : avatar,
    );
  }

  Widget _seal(ZxTokens t) {
    final double radius = size * 0.15;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.seal,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: t.primaryGlow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.08),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius * 0.6),
          border: Border.all(
            color: t.onPrimary.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Text(
          _initial,
          style: TextStyle(
            fontFamily: ZxFonts.display,
            fontFamilyFallback: ZxFonts.displayFallback,
            fontSize: size * 0.46,
            height: 1,
            color: t.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _realName(ZxTokens t) {
    final Color hue = t.channelFor(name);
    // Some channel hues are too light for text on their own tint; pull the
    // letter toward ink so every hue holds 4.5:1.
    final Color letter = Color.lerp(hue, t.text, 0.3)!;
    final BorderRadius radius = BorderRadius.circular(size * 0.24);
    final Widget initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: Color.lerp(hue, t.surface, 0.82),
        border: Border.all(color: t.line),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: size * 0.42,
          height: 1,
          fontWeight: FontWeight.w600,
          color: letter,
        ),
      ),
    );
    final String url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return initial;
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initial,
      ),
    );
  }
}
