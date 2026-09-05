import 'package:flutter/material.dart';

import '../models/football/match_fixture.dart';
import '../models/football/team.dart';

class FootballMatchCard extends StatelessWidget {
  final MatchFixture match;
  final VoidCallback onTap;

  const FootballMatchCard({super.key, required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: _TeamLabel(team: match.homeTeam)),
              _CenterInfo(match: match),
              Expanded(child: _TeamLabel(team: match.awayTeam, alignEnd: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamLabel extends StatelessWidget {
  final Team team;
  final bool alignEnd;

  const _TeamLabel({required this.team, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    final crest = team.crestUrl != null
        ? Image.network(
            team.crestUrl!,
            width: 28,
            height: 28,
            errorBuilder: (_, _, _) => const Icon(Icons.sports_soccer, size: 24),
          )
        : const Icon(Icons.sports_soccer, size: 24);

    final name = Flexible(
      child: Text(
        team.shortName ?? team.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );

    final children = alignEnd ? [name, const SizedBox(width: 8), crest] : [crest, const SizedBox(width: 8), name];
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: children,
    );
  }
}

class _CenterInfo extends StatelessWidget {
  final MatchFixture match;

  const _CenterInfo({required this.match});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (match.isFinished || match.isLive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (match.isLive)
              Text('LIVE', style: TextStyle(color: colorScheme.error, fontSize: 11)),
          ],
        ),
      );
    }

    final local = match.utcKickoff.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
