import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../screens/player_screen.dart';
import '../services/favorites_store.dart';

class MediaTile extends StatelessWidget {
  final MediaItem item;

  const MediaTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final isFavorite = FavoritesStore.instance.isFavorite(item.streamUrl);
        return ListTile(
          leading: item.logoUrl != null
              ? Image.network(
                  item.logoUrl!,
                  width: 40,
                  height: 40,
                  errorBuilder: (_, _, _) => const Icon(Icons.tv),
                )
              : const Icon(Icons.tv),
          title: Text(item.name),
          trailing: IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
            ),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => FavoritesStore.instance.toggle(item),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
            );
          },
        );
      },
    );
  }
}
