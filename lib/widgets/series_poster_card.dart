import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../screens/series_detail_screen.dart';
import '../services/xtream_api_client.dart';

class SeriesPosterCard extends StatelessWidget {
  final XtreamApiClient client;
  final SeriesSummary series;

  const SeriesPosterCard({super.key, required this.client, required this.series});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeriesDetailScreen(client: client, series: series),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: series.coverUrl != null
                  ? Image.network(
                      series.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _CoverFallback(),
                    )
                  : const _CoverFallback(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                series.name,
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

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.video_library,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
