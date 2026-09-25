import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

/// The rounded-square app-bar button of the handoff (A2, N1, S1, P2).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: ZxRadius.buttonAll,
            side: BorderSide(color: t.line),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: ZxRadius.buttonAll,
            ),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}
