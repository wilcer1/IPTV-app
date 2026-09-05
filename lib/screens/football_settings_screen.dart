import 'package:flutter/material.dart';

import '../models/football/competition.dart';
import '../models/football/team.dart';
import '../services/football_api_client.dart';
import '../services/football_preferences_store.dart';

class FootballSettingsScreen extends StatefulWidget {
  const FootballSettingsScreen({super.key});

  @override
  State<FootballSettingsScreen> createState() => _FootballSettingsScreenState();
}

class _FootballSettingsScreenState extends State<FootballSettingsScreen> {
  final _store = FootballPreferencesStore();
  final _apiKeyController = TextEditingController();

  FootballApiClient? _client;
  bool _validating = false;
  String? _error;

  List<Competition> _competitions = [];
  final Set<String> _favoriteCompetitions = {};
  final Set<int> _favoriteTeams = {};
  final Map<String, List<Team>> _teamsByCompetition = {};
  final Set<String> _loadingTeamsFor = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apiKey = await _store.loadApiKey();
    final favoriteCompetitions = await _store.loadFavoriteCompetitions();
    final favoriteTeams = await _store.loadFavoriteTeams();
    if (!mounted) return;

    setState(() {
      _favoriteCompetitions.addAll(favoriteCompetitions);
      _favoriteTeams.addAll(favoriteTeams);
    });

    if (apiKey != null) {
      _apiKeyController.text = apiKey;
      await _connect(apiKey, silent: true);
    }
  }

  Future<void> _connect(String apiKey, {bool silent = false}) async {
    setState(() {
      _validating = true;
      _error = null;
    });

    final client = FootballApiClient(apiKey);
    try {
      final competitions = await client.getCompetitions();
      await _store.saveApiKey(apiKey);
      if (!mounted) return;
      setState(() {
        _client = client;
        _competitions = competitions;
      });
    } catch (e) {
      if (!silent) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _toggleCompetition(Competition competition, bool selected) async {
    setState(() {
      if (selected) {
        _favoriteCompetitions.add(competition.code);
      } else {
        _favoriteCompetitions.remove(competition.code);
      }
    });
    await _store.saveFavoriteCompetitions(_favoriteCompetitions);
  }

  Future<void> _toggleTeam(Team team, bool selected) async {
    setState(() {
      if (selected) {
        _favoriteTeams.add(team.id);
      } else {
        _favoriteTeams.remove(team.id);
      }
    });
    await _store.saveFavoriteTeams(_favoriteTeams);
  }

  Future<void> _loadTeams(Competition competition) async {
    if (_teamsByCompetition.containsKey(competition.code) || _client == null) return;
    setState(() => _loadingTeamsFor.add(competition.code));
    try {
      final teams = await _client!.getTeams(competition.code);
      if (!mounted) return;
      setState(() => _teamsByCompetition[competition.code] = teams);
    } catch (_) {
      // Leave the section empty; the user can retry by collapsing/expanding.
    } finally {
      if (mounted) setState(() => _loadingTeamsFor.remove(competition.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Football preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'API key (football-data.org)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Free account: football-data.org/client/register',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: _validating
                ? null
                : () => _connect(_apiKeyController.text.trim()),
            child: _validating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save & connect'),
          ),
          if (_client != null) ...[
            const SizedBox(height: 24),
            Text('Favorite leagues', style: Theme.of(context).textTheme.titleMedium),
            const Text('Tap a league to also pick favorite teams within it.'),
            const SizedBox(height: 8),
            for (final competition in _competitions)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  leading: competition.emblemUrl != null
                      ? Image.network(competition.emblemUrl!, width: 32, height: 32,
                          errorBuilder: (_, _, _) => const Icon(Icons.sports_soccer))
                      : const Icon(Icons.sports_soccer),
                  title: Text(competition.name),
                  trailing: Checkbox(
                    value: _favoriteCompetitions.contains(competition.code),
                    onChanged: (value) =>
                        _toggleCompetition(competition, value ?? false),
                  ),
                  onExpansionChanged: (expanded) {
                    if (expanded) _loadTeams(competition);
                  },
                  children: [
                    if (_loadingTeamsFor.contains(competition.code))
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      for (final team in _teamsByCompetition[competition.code] ?? [])
                        CheckboxListTile(
                          value: _favoriteTeams.contains(team.id),
                          onChanged: (value) => _toggleTeam(team, value ?? false),
                          title: Text(team.name),
                        ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
