import 'package:flutter/material.dart';

import '../../core/widgets/app_surfaces.dart';
import '../favorites/favorites_page.dart';

class MyFavoritesPage extends StatelessWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageTopActions(leading: BackButton()),
      body: const FavoritesPage(),
    );
  }
}
