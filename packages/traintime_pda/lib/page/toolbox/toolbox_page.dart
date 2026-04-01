// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:watermeter/model/toolbox_addresses.dart';
import 'package:watermeter/page/toolbox/webview_list_tile.dart';

class ToolBoxPage extends StatefulWidget {
  const ToolBoxPage({super.key});

  @override
  State<ToolBoxPage> createState() => _ToolBoxPageState();
}

class _ToolBoxPageState extends State<ToolBoxPage> {
  @override
  Widget build(BuildContext context) {
    final List<WebViewAddresses> addresses = toolboxEntries
        .map(
          (entry) => WebViewAddresses(
            name: FlutterI18n.translate(context, entry.nameKey),
            url: entry.url,
            description: FlutterI18n.translate(context, entry.descriptionKey),
            iconData: entry.iconData,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: I18nText("toolbox.title"),
      ),
      body: ListView(
        children: addresses
            .map((entry) => WebViewListTile(data: entry))
            .toList(growable: false),
      ),
    );
  }
}
