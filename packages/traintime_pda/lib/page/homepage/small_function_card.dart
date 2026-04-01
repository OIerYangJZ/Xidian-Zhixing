// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/page/homepage/home_card_padding.dart';

class SmallFunctionCard extends StatelessWidget {
  final IconData icon;
  final String nameKey;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? topRightAction;

  const SmallFunctionCard({
    super.key,
    required this.icon,
    required this.nameKey,
    this.onPressed,
    this.onLongPress,
    this.topRightAction,
  });

  @override
  Widget build(BuildContext context) {
    final card =
        [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                FlutterI18n.translate(context, nameKey),
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ]
            .toColumn(mainAxisAlignment: MainAxisAlignment.center)
            .alignment(Alignment.center)
            .withHomeCardStyle(
              context,
              onPressed: onPressed,
              onLongPress: onLongPress,
            );

    if (topRightAction == null) {
      return card;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: card),
        Positioned(top: 4, right: 4, child: topRightAction!),
      ],
    );
  }
}
