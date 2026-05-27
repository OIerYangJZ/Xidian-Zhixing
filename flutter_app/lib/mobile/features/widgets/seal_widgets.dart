import 'package:flutter/material.dart';
import '../../../core/theme/shared_colors.dart';

enum SealBadgeType { solid, hollow, light }

class SealBadge extends StatelessWidget {
  final String text;
  final SealBadgeType type;

  const SealBadge({super.key, required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    switch (type) {
      case SealBadgeType.solid:
        bgColor = SharedColors.primary;
        textColor = Colors.white;
        border = Border.all(color: SharedColors.deep, width: 0.5);
        break;
      case SealBadgeType.hollow:
        bgColor = Colors.white;
        textColor = SharedColors.primary;
        border = Border.all(color: SharedColors.primary, width: 0.8);
        break;
      case SealBadgeType.light:
        bgColor = SharedColors.softRed;
        textColor = SharedColors.deep;
        border = Border.all(
          color: SharedColors.primary.withValues(alpha: 0.15),
          width: 0.5,
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: border,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}

class SealAvatar extends StatelessWidget {
  final String text;
  final double size;

  const SealAvatar({super.key, required this.text, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final char = text.isNotEmpty ? text.characters.first : '匿';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SharedColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SharedColors.deep, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SharedColors.deep.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          char,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
