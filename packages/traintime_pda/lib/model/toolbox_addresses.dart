// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class WebViewAddresses {
  final String name;
  final String url;
  final String description;
  final IconData iconData;

  const WebViewAddresses({
    required this.name,
    required this.url,
    required this.description,
    required this.iconData,
  });
}

class ToolboxEntry {
  final String id;
  final String nameKey;
  final String descriptionKey;
  final String url;
  final IconData iconData;

  const ToolboxEntry({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.url,
    required this.iconData,
  });
}

const List<ToolboxEntry> toolboxEntries = <ToolboxEntry>[
  ToolboxEntry(
    id: "toolbox_payment",
    nameKey: "toolbox.payment",
    descriptionKey: "toolbox.payment_description",
    url: "https://payment.xidian.edu.cn/MNetWorkUI/showPublic",
    iconData: MingCuteIcons.mgc_exchange_cny_line,
  ),
  ToolboxEntry(
    id: "toolbox_drinkingwater",
    nameKey: "toolbox.drinkingwater",
    descriptionKey: "toolbox.drinkingwater_description",
    url: "https://order.xidian.edu.cn/mobile/thirdoauth/oauth2Xidian/1",
    iconData: MingCuteIcons.mgc_drop_line,
  ),
  ToolboxEntry(
    id: "toolbox_repair",
    nameKey: "toolbox.repair",
    descriptionKey: "toolbox.repair_description",
    url:
        "https://ids.xidian.edu.cn/authserver/login?service="
        "https%3A%2F%2Fids.xidian.edu.cn%2Fauthserver%2Foauth2.0%2F"
        "callbackAuthorize%3Fclient_id%3D869608421533880320%26"
        "redirect_uri%3Dhttp%253A%252F%252Frepair.xidian.edu.cn%252F"
        "appsys%252FxidianCasLogin%252FoauthLogin%26response_type%3D"
        "code%26state%3Dhome%26client_name%3DCasOAuthClient",
    iconData: MingCuteIcons.mgc_tool_line,
  ),
  ToolboxEntry(
    id: "toolbox_reserve",
    nameKey: "toolbox.reserve",
    descriptionKey: "toolbox.reserve_description",
    url: "http://libspace.xidian.edu.cn",
    iconData: MingCuteIcons.mgc_building_4_line,
  ),
  ToolboxEntry(
    id: "toolbox_mobile",
    nameKey: "toolbox.mobile",
    descriptionKey: "toolbox.mobile_description",
    url: "https://xxcapp.xidian.edu.cn/site/xidianPage/home",
    iconData: MingCuteIcons.mgc_chat_2_line,
  ),
  ToolboxEntry(
    id: "toolbox_network",
    nameKey: "toolbox.network",
    descriptionKey: "toolbox.network_description",
    url: "https://zfw.xidian.edu.cn",
    iconData: MingCuteIcons.mgc_wifi_line,
  ),
  ToolboxEntry(
    id: "toolbox_physics",
    nameKey: "toolbox.physics",
    descriptionKey: "toolbox.physics_description",
    url: "https://experiment-helper.wizzstudio.com/#/",
    iconData: MingCuteIcons.mgc_counter_2_line,
  ),
  ToolboxEntry(
    id: "toolbox_discover",
    nameKey: "toolbox.discover",
    descriptionKey: "toolbox.discover_description",
    url: "https://nav.xdruisi.cn/",
    iconData: MingCuteIcons.mgc_web_line,
  ),
];
