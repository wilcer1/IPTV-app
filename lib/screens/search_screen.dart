import 'package:flutter/material.dart';

import '../models/epg_program.dart';
import '../models/media_item.dart';
import '../services/xtream_api_client.dart';
import '../widgets/media_tile.dart';
import 'player_screen.dart';

class _ProgramMatch {
  final EpgProgram program;
  final MediaItem channel;

  const _ProgramMatch({required this.program, required this.channel});
}

class SearchScreen extends StatefulWidget {
  final XtreamApiClient client;

  const SearchScreen({super.key, required this.client});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Future<(List<MediaItem>, List<EpgProgram>)> _dataFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<(List<MediaItem>, List<EpgProgram>)> _loadData() async {
    final channels = await widget.client.getLiveStreams();
    List<EpgProgram> programs;
    try {
      programs = await widget.client.getFullEpg();
    } catch (_) {
      // EPG is a bonus feature; fall back to channel-name-only search if it's
      // unavailable or too slow/unsupported on this provider.
      programs = const [];
    }
    return (channels, programs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search channels or programs...',
            border: InputBorder.none,
          ),
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontSize: 18),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: FutureBuilder<(List<MediaItem>, List<EpgProgram>)>(
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
              child: Text('Start typing to search channels or programs.'),
            );
          }

          final (channels, programs) = snapshot.data!;

          final channelMatches =
              channels.where((c) => c.name.toLowerCase().contains(query)).toList();

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

          if (channelMatches.isEmpty && programMatches.isEmpty) {
            return const Center(child: Text('No matching channels or programs.'));
          }

          return ListView(
            children: [
              for (final channel in channelMatches) MediaTile(item: channel),
              if (programMatches.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Programs', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
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
          );
        },
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
