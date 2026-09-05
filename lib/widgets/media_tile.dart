import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../screens/player_screen.dart';
import '../services/favorites_store.dart';
import 'deferred_network_image.dart';

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
          child: Row(
            children: [
              // The tappable row body and the favorite button must be
              // siblings, not one nested inside the other's tap/focus
              // area. A D-pad's directional focus search only considers
              // candidates outside the currently-focused widget's bounds,
              // so a trailing IconButton fully enclosed by a ListTile's
              // own focus rect (as this used to be) is unreachable by
              // remote — confirmed on a real Google TV device.
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlayerScreen(item: item)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: item.logoUrl != null
                                ? DeferredNetworkImage(
                                    url: item.logoUrl!,
                                    cacheWidth: 88,
                                    cacheHeight: 88,
                                    placeholder: const _LogoFallback(),
                                  )
                                : const _LogoFallback(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(item.name)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : null,
                ),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => FavoritesStore.instance.toggle(item),
              ),
            ],
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
