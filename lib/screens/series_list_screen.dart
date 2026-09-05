import 'package:flutter/material.dart';

import '../models/series_summary.dart';
import '../services/xtream_api_client.dart';
import '../widgets/series_poster_card.dart';

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
      body: FutureBuilder<List<SeriesSummary>>(
        future: _seriesFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(widget.title)),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(child: Center(child: Text('${snapshot.error}')))
              else if (snapshot.data!.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No series found in this category.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SeriesPosterCard(
                        client: widget.client,
                        series: snapshot.data![index],
                      ),
                      childCount: snapshot.data!.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
