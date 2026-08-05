import 'package:flutter/material.dart';

import '../favorites/favorites_page.dart';
import '../../core/l10n/ui_text.dart';

class MyFavoritesPage extends StatelessWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, zh: '我的收藏', en: 'My favorites')),
      ),
      body: const FavoritesPage(),
    );
  }
}
