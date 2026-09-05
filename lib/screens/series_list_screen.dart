import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../services/xtream_api_client.dart';
import '../widgets/series_tile.dart';

class SeriesListScreen extends StatefulWidget {
  final String title;
  final XtreamApiClient client;
  final Future<List<SeriesSummary>> Function() fetchSeries;

  const SeriesListScreen({
    super.key,
    required this.title,
    required this.client,
    required this.fetchSeries,
  });

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  late final Future<List<SeriesSummary>> _seriesFuture;

  @override
  void initState() {
    super.initState();
    _seriesFuture = widget.fetchSeries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<SeriesSummary>>(
        future: _seriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final series = snapshot.data!;
          if (series.isEmpty) {
            return const Center(child: Text('No series found in this category.'));
          }

          return ListView.builder(
            itemCount: series.length,
            itemBuilder: (context, index) =>
                SeriesTile(client: widget.client, series: series[index]),
          );
        },
      ),
    );
  }
}
