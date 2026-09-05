import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../screens/series_detail_screen.dart';
import '../services/xtream_api_client.dart';

class SeriesTile extends StatelessWidget {
  final XtreamApiClient client;
  final SeriesSummary series;

  const SeriesTile({super.key, required this.client, required this.series});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: series.coverUrl != null
          ? Image.network(
              series.coverUrl!,
              width: 40,
              height: 40,
              errorBuilder: (_, _, _) => const Icon(Icons.movie),
            )
          : const Icon(Icons.movie),
      title: Text(series.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(client: client, series: series),
          ),
        );
      },
    );
  }
}
