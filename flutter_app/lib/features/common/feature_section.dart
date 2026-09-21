import 'package:flutter/material.dart';

/// A flat, divided content section used by the web feature pages.
class FeatureSection extends StatelessWidget {
  const FeatureSection({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
