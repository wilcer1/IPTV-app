import 'package:flutter/material.dart';

import '../models/epg_program.dart';
import '../models/media_item.dart';
import '../models/series_summary.dart';
import '../services/xtream_api_client.dart';
import '../widgets/media_tile.dart';
import '../widgets/series_tile.dart';
import '../widgets/tv_text_field.dart';
import 'player_screen.dart';

class _ProgramMatch {
  final EpgProgram program;
  final MediaItem channel;

  const _ProgramMatch({required this.program, required this.channel});
}

typedef _SearchData = (
  List<MediaItem> channels,
  List<MediaItem> movies,
  List<SeriesSummary> series,
  List<EpgProgram> programs,
);

class SearchScreen extends StatefulWidget {
  final XtreamApiClient client;
  final String? initialQuery;

  const SearchScreen({super.key, required this.client, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Future<_SearchData> _dataFuture;
  late String _query;
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _queryController = TextEditingController(text: _query);
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<_SearchData> _loadData() async {
    final channels = await widget.client.getLiveStreams();
    final movies = await widget.client.getVodStreams();
    final series = await widget.client.getSeries();

    List<EpgProgram> programs;
    try {
      programs = await widget.client.getFullEpg();
    } catch (_) {
      // EPG is a bonus feature; fall back to name-only search if it's
      // unavailable or too slow/unsupported on this provider.
      programs = const [];
    }
    return (channels, movies, series, programs);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TvTextField(
                  controller: _queryController,
                  autofocus: widget.initialQuery != null,
                  keyboardTitle: 'Search',
                  decoration: InputDecoration(
                    hintText: 'Search channels, movies, series, programs...',
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<_SearchData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('${snapshot.error}'));
                  }

                  final query = _query.trim().toLowerCase();
                  if (query.isEmpty) {
                    return const Center(
                      child: Text('Start typing to search channels, movies, series, or programs.'),
                    );
                  }

                  final (channels, movies, series, programs) = snapshot.data!;

                  final channelMatches =
                      channels.where((c) => c.name.toLowerCase().contains(query)).toList();
                  final movieMatches =
                      movies.where((m) => m.name.toLowerCase().contains(query)).toList();
                  final seriesMatches =
                      series.where((s) => s.name.toLowerCase().contains(query)).toList();

                  final channelsByEpgId = <String, MediaItem>{
                    for (final c in channels)
                      if (c.epgChannelId != null) c.epgChannelId!: c,
                  };
                  final programMatches = programs
                      .where((p) => p.title.toLowerCase().contains(query))
                      .map((p) {
                        final channel = channelsByEpgId[p.channelId];
                        return channel == null ? null : _ProgramMatch(program: p, channel: channel);
                      })
                      .whereType<_ProgramMatch>()
                      .toList()
                    ..sort((a, b) => a.program.start.compareTo(b.program.start));

                  final hasResults = channelMatches.isNotEmpty ||
                      movieMatches.isNotEmpty ||
                      seriesMatches.isNotEmpty ||
                      programMatches.isNotEmpty;
                  if (!hasResults) {
                    return const Center(child: Text('No matching results.'));
                  }

                  return ListView(
                    children: [
                      if (channelMatches.isNotEmpty) ...[
                        _SectionHeader('Live TV'),
                        for (final channel in channelMatches) MediaTile(item: channel),
                      ],
                      if (movieMatches.isNotEmpty) ...[
                        _SectionHeader('Movies'),
                        for (final movie in movieMatches) MediaTile(item: movie),
                      ],
                      if (seriesMatches.isNotEmpty) ...[
                        _SectionHeader('Series'),
                        for (final s in seriesMatches)
                          SeriesTile(client: widget.client, series: s),
                      ],
                      if (programMatches.isNotEmpty) ...[
                        _SectionHeader('Programs'),
                        for (final match in programMatches)
                          ListTile(
                            leading: const Icon(Icons.live_tv),
                            title: Text(match.program.title),
                            subtitle: Text(
                              '${match.channel.name} · ${_formatTime(match.program.start)}',
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(item: match.channel),
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $hour:$minute';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
