import 'package:shared_preferences/shared_preferences.dart';

import '../models/xtream_credentials.dart';

class CredentialsStore {
  static const _hostKey = 'xtream_host';
  static const _usernameKey = 'xtream_username';
  static const _passwordKey = 'xtream_password';

  Future<void> save(XtreamCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, credentials.host);
    await prefs.setString(_usernameKey, credentials.username);
    await prefs.setString(_passwordKey, credentials.password);
  }

  Future<XtreamCredentials?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);
    if (host == null || username == null || password == null) return null;
    return XtreamCredentials(host: host, username: username, password: password);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }
}
