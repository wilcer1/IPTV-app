import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/series_details.dart';
import '../models/series_summary.dart';
import '../services/iptv_client.dart';
import '../services/watch_progress_store.dart';
import '../widgets/media_tile.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final IptvClient client;
  final SeriesSummary series;

  const SeriesDetailScreen({
    super.key,
    required this.client,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late final Future<SeriesDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.client.getSeriesInfo(widget.series.seriesId);
  }

  /// Where the big button should send you: back into what you were watching,
  /// on to the next episode, or to the very first one.
  ({MediaItem target, String label}) _playTarget(SeriesDetails details) {
    final latest = WatchProgressStore.instance.latestForSeries(widget.series.seriesId);
    if (latest != null) {
      final episode = latest.item.episodeLabel;
      final verb = latest.upNext ? 'Play' : 'Resume';
      return (
        target: latest.item,
        label: episode == null ? verb : '$verb $episode',
      );
    }
    final first = details.allEpisodes.first;
    final episode = first.episodeLabel;
    return (target: first, label: episode == null ? 'Play' : 'Play $episode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: FutureBuilder<SeriesDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final details = snapshot.data!;
          if (details.allEpisodes.isEmpty) {
            return const Center(child: Text('No episodes found.'));
          }

          final queue = details.allEpisodes;

          return ListenableBuilder(
            listenable: WatchProgressStore.instance,
            builder: (context, _) {
              final play = _playTarget(details);
              final targetSeason = play.target.season?.toString();

              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(item: play.target, queue: queue),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(play.label),
                      ),
                    ),
                  ),
                  if (details.plot != null && details.plot!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(details.plot!),
                    ),
                  for (final season in details.seasons)
                    ExpansionTile(
                      key: PageStorageKey('season-${season.seasonNumber}'),
                      initiallyExpanded: season.seasonNumber == targetSeason,
                      title: Text('Season ${season.seasonNumber}'),
                      children: [
                        for (final episode in season.episodes)
                          MediaTile(item: episode, queue: queue),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
