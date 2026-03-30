// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

enum EmptyListViewType { reading, singing, rolling, defaultimg }

class EmptyListView extends StatelessWidget {
  final String text;

  const EmptyListView({
    super.key,
    required this.text,
    this.type = EmptyListViewType.defaultimg,
  });

  final EmptyListViewType type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case EmptyListViewType.reading:
        icon = Icons.auto_stories_outlined;
      case EmptyListViewType.rolling:
        icon = Icons.calendar_today_outlined;
      default:
        icon = Icons.inbox_outlined;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Theme.of(context).colorScheme.outline),
        const Divider(color: Colors.transparent),
        Text(text),
      ],
    );
  }
}
