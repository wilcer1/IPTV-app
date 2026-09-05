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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: item.logoUrl != null
                    ? Image.network(
                        item.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _LogoFallback(),
                      )
                    : const _LogoFallback(),
              ),
            ),
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
          ),
        );
      },
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.tv, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
