import 'package:flutter/material.dart';

import '../services/watch_progress_store.dart';
import 'deferred_network_image.dart';

class ContinueWatchingCard extends StatelessWidget {
  static const width = 150.0;
  static const posterHeight = 225.0;

  final ContinueItem entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const ContinueWatchingCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  String get _title => entry.item.seriesTitle ?? entry.item.name;

  String get _subtitle {
    final parts = <String>[
      if (entry.item.episodeLabel != null) entry.item.episodeLabel!,
      if (entry.upNext)
        'Up next'
      else if (entry.remaining != null)
        describeRemaining(entry.remaining!),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = entry.fraction;

    return SizedBox(
      width: width,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: posterHeight,
              child: InkWell(
                onTap: onOpen,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    entry.item.logoUrl != null
                        ? DeferredNetworkImage(
                            url: entry.item.logoUrl!,
                            width: double.infinity,
                            cacheWidth: 300,
                            placeholder: _Fallback(colorScheme: colorScheme),
                          )
                        : _Fallback(colorScheme: colorScheme),
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    if (fraction != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                          backgroundColor: Colors.black54,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                _title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // A sibling of the poster rather than an overlay on it, so a
            // D-pad can reach it (focus search only finds candidates outside
            // the current focus rect).
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                iconSize: 18,
                tooltip: 'Remove from Continue Watching',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final ColorScheme colorScheme;

  const _Fallback({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.movie, size: 40, color: colorScheme.onSurfaceVariant),
    );
  }
}
