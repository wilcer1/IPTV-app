import 'package:flutter/material.dart';

import '../models/epg_program.dart';
import '../models/football/match_fixture.dart';
import '../models/football/team.dart';
import '../models/media_item.dart';
import '../services/xtream_api_client.dart';
import '../widgets/media_tile.dart';
import 'search_screen.dart';

class _StreamMatches {
  final List<MediaItem> strong;
  final List<MediaItem> weak;

  const _StreamMatches({required this.strong, required this.weak});
}

class FootballMatchScreen extends StatefulWidget {
  final XtreamApiClient xtreamClient;
  final MatchFixture match;

  const FootballMatchScreen({
    super.key,
    required this.xtreamClient,
    required this.match,
  });

  @override
  State<FootballMatchScreen> createState() => _FootballMatchScreenState();
}

class _FootballMatchScreenState extends State<FootballMatchScreen> {
  late final Future<_StreamMatches> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = _findStreams();
  }

  Future<_StreamMatches> _findStreams() async {
    final channels = await widget.xtreamClient.getLiveStreams();

    List<EpgProgram> programs;
    try {
      programs = await widget.xtreamClient.getFullEpg();
    } catch (_) {
      programs = const [];
    }

    final channelsByEpgId = <String, MediaItem>{
      for (final c in channels)
        if (c.epgChannelId != null) c.epgChannelId!: c,
    };

    final homeAliases = widget.match.homeTeam.searchAliases;
    final awayAliases = widget.match.awayTeam.searchAliases;
    final windowStart = widget.match.utcKickoff.subtract(const Duration(hours: 1));
    final windowEnd = widget.match.utcKickoff.add(const Duration(hours: 4));

    final strong = <String, MediaItem>{};
    final weak = <String, MediaItem>{};

    for (final program in programs) {
      if (program.start.isBefore(windowStart) || program.start.isAfter(windowEnd)) {
        continue;
      }

      final channel = channelsByEpgId[program.channelId];
      if (channel == null) continue;

      final titleNorm = normalizeTeamText(program.title);
      final hasHome = homeAliases.any(titleNorm.contains);
      final hasAway = awayAliases.any(titleNorm.contains);

      if (hasHome && hasAway) {
        strong[channel.streamUrl] = channel;
      } else if (hasHome || hasAway) {
        weak[channel.streamUrl] = channel;
      }
    }

    return _StreamMatches(strong: strong.values.toList(), weak: weak.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.homeTeam.shortName ?? match.homeTeam.name} vs '
            '${match.awayTeam.shortName ?? match.awayTeam.name}'),
      ),
      body: FutureBuilder<_StreamMatches>(
        future: _streamsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final result = snapshot.data!;
          if (result.strong.isEmpty && result.weak.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off,
                        size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    const Text(
                      'No stream found automatically for this match in your program guide.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              client: widget.xtreamClient,
                              initialQuery: match.homeTeam.shortName ?? match.homeTeam.name,
                            ),
                          ),
                        );
                      },
                      child: const Text('Search manually'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (result.strong.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Likely streams', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final item in result.strong) MediaTile(item: item),
              ],
              if (result.weak.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Possible streams', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final item in result.weak) MediaTile(item: item),
              ],
            ],
          );
        },
      ),
    );
  }
}
