import 'package:flutter/material.dart';

import '../models/series_details.dart';
import '../models/series_summary.dart';
import '../services/xtream_api_client.dart';
import '../widgets/media_tile.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XtreamApiClient client;
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
          if (details.seasons.isEmpty) {
            return const Center(child: Text('No episodes found.'));
          }

          return ListView(
            children: [
              if (details.plot != null && details.plot!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(details.plot!),
                ),
              for (final season in details.seasons)
                ExpansionTile(
                  title: Text('Season ${season.seasonNumber}'),
                  children: [
                    for (final episode in season.episodes)
                      MediaTile(item: episode),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
