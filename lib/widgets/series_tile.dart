import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../screens/series_detail_screen.dart';
import '../services/xtream_api_client.dart';
import 'deferred_network_image.dart';

class SeriesTile extends StatelessWidget {
  final XtreamApiClient client;
  final SeriesSummary series;

  const SeriesTile({super.key, required this.client, required this.series});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: series.coverUrl != null
                ? DeferredNetworkImage(
                    url: series.coverUrl!,
                    cacheWidth: 88,
                    cacheHeight: 88,
                    placeholder: const _CoverFallback(),
                  )
                : const _CoverFallback(),
          ),
        ),
        title: Text(series.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeriesDetailScreen(client: client, series: series),
            ),
          );
        },
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
      child: Icon(Icons.movie, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
