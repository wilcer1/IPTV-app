import 'package:flutter/material.dart';

import '../services/watch_progress_store.dart';

/// Thin red-ish bar for the bottom edge of a poster, shown only for
/// something part-way through. Purely visual (not focusable), so it can sit
/// on top of a tappable poster without getting in a D-pad's way.
class WatchProgressBar extends StatelessWidget {
  final String itemId;

  const WatchProgressBar({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WatchProgressStore.instance,
      builder: (context, _) {
        final fraction = WatchProgressStore.instance.progressFraction(itemId);
        if (fraction == null) return const SizedBox.shrink();
        return LinearProgressIndicator(
          value: fraction,
          minHeight: 4,
          backgroundColor: Colors.black54,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}

/// A check mark for anything finished.
class WatchedBadge extends StatelessWidget {
  final String itemId;

  const WatchedBadge({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WatchProgressStore.instance,
      builder: (context, _) {
        if (!WatchProgressStore.instance.isCompleted(itemId)) {
          return const SizedBox.shrink();
        }
        return const DecoratedBox(
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.check_circle, size: 20, color: Colors.white),
          ),
        );
      },
    );
  }
}

/// "Watched" or a progress bar with time left, for list rows.
class WatchStatusLine extends StatelessWidget {
  final String itemId;

  const WatchStatusLine({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WatchProgressStore.instance,
      builder: (context, _) {
        final store = WatchProgressStore.instance;
        final colorScheme = Theme.of(context).colorScheme;
        final labelStyle = Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: colorScheme.onSurfaceVariant);

        if (store.isCompleted(itemId)) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text('Watched', style: labelStyle),
              ],
            ),
          );
        }

        final fraction = store.progressFraction(itemId);
        if (fraction == null) return const SizedBox.shrink();
        final remaining = store.entryFor(itemId)!.remaining;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: fraction, minHeight: 3),
              ),
              const SizedBox(height: 3),
              Text(describeRemaining(remaining), style: labelStyle),
            ],
          ),
        );
      },
    );
  }
}
