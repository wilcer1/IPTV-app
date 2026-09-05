import 'package:flutter/material.dart';

import '../models/football/match_fixture.dart';
import '../services/football_api_client.dart';
import '../services/football_preferences_store.dart';
import '../services/xtream_api_client.dart';
import 'football_match_screen.dart';
import 'football_settings_screen.dart';
import '../widgets/football_match_card.dart';

class FootballScreen extends StatefulWidget {
  final XtreamApiClient client;

  const FootballScreen({super.key, required this.client});

  @override
  State<FootballScreen> createState() => _FootballScreenState();
}

class _FootballScreenState extends State<FootballScreen> {
  final _store = FootballPreferencesStore();

  FootballApiClient? _footballClient;
  Set<String> _favoriteCompetitions = {};
  Set<int> _favoriteTeams = {};
  DateTime _date = DateTime.now();
  bool _myTeamsOnly = false;

  Future<List<MatchFixture>>? _matchesFuture;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndMatches();
  }

  Future<void> _loadPreferencesAndMatches() async {
    setState(() => _loadingPrefs = true);
    final apiKey = await _store.loadApiKey();
    final favoriteCompetitions = await _store.loadFavoriteCompetitions();
    final favoriteTeams = await _store.loadFavoriteTeams();
    if (!mounted) return;

    setState(() {
      _footballClient = apiKey == null ? null : FootballApiClient(apiKey);
      _favoriteCompetitions = favoriteCompetitions;
      _favoriteTeams = favoriteTeams;
      _loadingPrefs = false;
    });
    _reloadMatches();
  }

  void _reloadMatches() {
    final client = _footballClient;
    if (client == null || _favoriteCompetitions.isEmpty) {
      setState(() => _matchesFuture = Future.value(const []));
      return;
    }
    setState(() {
      _matchesFuture = client.getMatchesForDate(_date, _favoriteCompetitions.toList());
    });
  }

  void _changeDate(int deltaDays) {
    setState(() => _date = _date.add(Duration(days: deltaDays)));
    _reloadMatches();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FootballSettingsScreen()),
    );
    _loadPreferencesAndMatches();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'Today';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Football'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : _footballClient == null
              ? _EmptyState(
                  icon: Icons.sports_soccer,
                  message: 'Add a football-data.org API key to see today\'s matches.',
                  actionLabel: 'Set up',
                  onAction: _openSettings,
                )
              : _favoriteCompetitions.isEmpty
                  ? _EmptyState(
                      icon: Icons.sports_soccer,
                      message: 'Pick your favorite leagues to see matches here.',
                      actionLabel: 'Choose leagues',
                      onAction: _openSettings,
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => _changeDate(-1),
                              ),
                              Expanded(
                                child: Text(
                                  _formatDate(_date),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => _changeDate(1),
                              ),
                              if (_favoriteTeams.isNotEmpty)
                                FilterChip(
                                  label: const Text('My teams'),
                                  selected: _myTeamsOnly,
                                  onSelected: (value) {
                                    setState(() => _myTeamsOnly = value);
                                  },
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<List<MatchFixture>>(
                            future: _matchesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState != ConnectionState.done) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text('${snapshot.error}'));
                              }

                              var matches = snapshot.data!;
                              if (_myTeamsOnly) {
                                matches = matches
                                    .where((m) =>
                                        _favoriteTeams.contains(m.homeTeam.id) ||
                                        _favoriteTeams.contains(m.awayTeam.id))
                                    .toList();
                              }

                              if (matches.isEmpty) {
                                return const Center(child: Text('No matches on this day.'));
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: matches.length,
                                itemBuilder: (context, index) {
                                  final match = matches[index];
                                  return FootballMatchCard(
                                    match: match,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => FootballMatchScreen(
                                            xtreamClient: widget.client,
                                            match: match,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
