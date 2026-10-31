import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/iptv_client.dart';
import '../services/watch_progress_store.dart';
import '../widgets/continue_watching_card.dart';
import 'player_screen.dart';

/// The landing page: what to pick back up, Netflix-style.
class HomeFeedScreen extends StatelessWidget {
  final IptvClient client;

  /// Switches the main navigation to another tab (by index).
  final void Function(int index) onBrowse;

  const HomeFeedScreen({super.key, required this.client, required this.onBrowse});

  // For an episode we also want the rest of the show, so "Next episode"
  // works when starting from here. Best effort: if it can't be fetched
  // quickly, just play the episode on its own.
  Future<List<MediaItem>?> _queueFor(MediaItem item) async {
    final seriesId = item.seriesId;
    if (seriesId == null) return null;
    try {
      final details =
          await client.getSeriesInfo(seriesId).timeout(const Duration(seconds: 5));
      return details.allEpisodes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(BuildContext context, ContinueItem card) async {
    final queue = await _queueFor(card.item);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: card.item, queue: queue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: WatchProgressStore.instance,
        builder: (context, _) {
          final items = WatchProgressStore.instance.continueWatching;

          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Home')),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHome(onBrowse: onBrowse),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Continue Watching',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 350,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final card = items[index];
                        return ContinueWatchingCard(
                          entry: card,
                          onOpen: () => _open(context, card),
                          onRemove: () => WatchProgressStore.instance.dismiss(card),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  final void Function(int index) onBrowse;

  const _EmptyHome({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Nothing to continue yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Movies and episodes you start watching show up here, so you can pick up where you left off.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => onBrowse(2),
                  icon: const Icon(Icons.movie),
                  label: const Text('Browse movies'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => onBrowse(3),
                  icon: const Icon(Icons.video_library),
                  label: const Text('Browse series'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
