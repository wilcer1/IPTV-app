import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../screens/player_screen.dart';
import '../services/favorites_store.dart';
import 'deferred_network_image.dart';
import 'watch_progress_widgets.dart';

class MediaPosterCard extends StatelessWidget {
  final MediaItem item;

  const MediaPosterCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // Kept as its own InkWell (not wrapping the whole card) so its
            // tap/focus rect doesn't enclose the favorite button below — a
            // D-pad's directional focus search only finds candidates
            // outside the currently-focused widget's bounds, so a button
            // overlaid on top of this area (as it used to be) was
            // unreachable by remote. Confirmed on a real Google TV device.
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.logoUrl != null
                      ? DeferredNetworkImage(
                          url: item.logoUrl!,
                          width: double.infinity,
                          // Poster grid cells vary in exact pixel size, but
                          // cap decode resolution well above any realistic
                          // cell size to bound memory use.
                          cacheWidth: 300,
                          placeholder: const _PosterFallback(),
                        )
                      : const _PosterFallback(),
                  // Both overlays are non-interactive, so they don't
                  // disturb the poster's own tap/focus target.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: WatchProgressBar(itemId: item.id),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: WatchedBadge(itemId: item.id),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ListenableBuilder(
                  listenable: FavoritesStore.instance,
                  builder: (context, _) {
                    final isFavorite =
                        FavoritesStore.instance.isFavorite(item.streamUrl);
                    return IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? Colors.amber : null,
                      ),
                      onPressed: () => FavoritesStore.instance.toggle(item),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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
