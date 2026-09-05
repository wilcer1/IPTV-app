import 'package:flutter/material.dart';

import '../services/favorites_store.dart';
import '../widgets/media_tile.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: FavoritesStore.instance,
        builder: (context, _) {
          final favorites = FavoritesStore.instance.all;

          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Favorites')),
              if (favorites.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_border,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No favorites yet. Tap the star on any channel to add it.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.builder(
                    itemCount: favorites.length,
                    itemBuilder: (context, index) => MediaTile(item: favorites[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
