import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/football/competition.dart';
import '../models/football/match_fixture.dart';
import '../models/football/team.dart';

class FootballApiException implements Exception {
  final String message;
  FootballApiException(this.message);

  @override
  String toString() => message;
}

class FootballApiClient {
  static const _baseUrl = 'https://api.football-data.org/v4';

  final String apiKey;

  const FootballApiClient(this.apiKey);

  Map<String, String> get _headers => {'X-Auth-Token': apiKey};

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw FootballApiException('Invalid or unauthorized API key.');
    }
    if (response.statusCode == 429) {
      throw FootballApiException('Rate limited by football-data.org, try again shortly.');
    }
    if (response.statusCode != 200) {
      throw FootballApiException('Request failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  /// Validates the key by hitting a cheap endpoint.
  Future<void> validateKey() async {
    await _get('/competitions');
  }

  Future<List<Competition>> getCompetitions() async {
    final data = await _get('/competitions') as Map<String, dynamic>;
    final competitions = data['competitions'] as List<dynamic>;
    return competitions
        .map((e) => e as Map<String, dynamic>)
        .where((e) => e['plan'] == null || e['plan'] == 'TIER_ONE')
        .map(Competition.fromJson)
        .toList();
  }

  Future<List<Team>> getTeams(String competitionCode) async {
    final data = await _get('/competitions/$competitionCode/teams') as Map<String, dynamic>;
    final teams = data['teams'] as List<dynamic>;
    return teams.map((e) => Team.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MatchFixture>> getMatchesForDate(
    DateTime date,
    List<String> competitionCodes,
  ) async {
    if (competitionCodes.isEmpty) return [];

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final data = await _get('/matches', {
      'dateFrom': dateStr,
      'dateTo': dateStr,
      'competitions': competitionCodes.join(','),
    }) as Map<String, dynamic>;

    final matches = data['matches'] as List<dynamic>? ?? [];
    return matches
        .map((e) => MatchFixture.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.utcKickoff.compareTo(b.utcKickoff));
  }
}
