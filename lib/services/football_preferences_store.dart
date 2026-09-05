import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FootballPreferencesStore {
  static const _apiKeyKey = 'football_api_key';
  static const _competitionsKey = 'football_favorite_competitions';
  static const _teamsKey = 'football_favorite_teams';

  static const _storage = FlutterSecureStorage();

  Future<String?> loadApiKey() => _storage.read(key: _apiKeyKey);

  Future<void> saveApiKey(String key) => _storage.write(key: _apiKeyKey, value: key);

  Future<void> clearApiKey() => _storage.delete(key: _apiKeyKey);

  Future<Set<String>> loadFavoriteCompetitions() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_competitionsKey) ?? const []).toSet();
  }

  Future<void> saveFavoriteCompetitions(Set<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_competitionsKey, codes.toList());
  }

  Future<Set<int>> loadFavoriteTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_teamsKey) ?? const [];
    return raw.map(int.parse).toSet();
  }

  Future<void> saveFavoriteTeams(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_teamsKey, ids.map((e) => e.toString()).toList());
  }
}
