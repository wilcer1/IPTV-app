import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../screens/player_screen.dart';
import '../services/favorites_store.dart';

class MediaPosterCard extends StatelessWidget {
  final MediaItem item;

  const MediaPosterCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.logoUrl != null
                      ? Image.network(
                          item.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _PosterFallback(),
                        )
                      : const _PosterFallback(),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: ListenableBuilder(
                      listenable: FavoritesStore.instance,
                      builder: (context, _) {
                        final isFavorite =
                            FavoritesStore.instance.isFavorite(item.streamUrl);
                        return CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              color: isFavorite ? Colors.amber : Colors.white,
                            ),
                            onPressed: () => FavoritesStore.instance.toggle(item),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
