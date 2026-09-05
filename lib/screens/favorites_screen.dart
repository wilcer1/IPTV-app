import 'package:flutter/material.dart';

import '../services/favorites_store.dart';
import '../widgets/media_tile.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListenableBuilder(
        listenable: FavoritesStore.instance,
        builder: (context, _) {
          final favorites = FavoritesStore.instance.all;
          if (favorites.isEmpty) {
            return const Center(
              child: Text('No favorites yet. Tap the star on any channel to add it.'),
            );
          }
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) => MediaTile(item: favorites[index]),
          );
        },
      ),
    );
  }
}
