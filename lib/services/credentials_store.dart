import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_config.dart';
import '../models/xtream_credentials.dart';

class CredentialsStore {
  static const _hostKey = 'xtream_host';
  static const _usernameKey = 'xtream_username';
  static const _passwordKey = 'xtream_password';
  static const _m3uUrlKey = 'm3u_url';
  static const _m3uEpgUrlKey = 'm3u_epg_url';

  static const _storage = FlutterSecureStorage();

  // Only one login is ever active, so saving one type wipes the other.
  Future<void> save(LoginConfig login) async {
    await clear();
    switch (login) {
      case XtreamLogin(:final credentials):
        await _storage.write(key: _hostKey, value: credentials.host);
        await _storage.write(key: _usernameKey, value: credentials.username);
        await _storage.write(key: _passwordKey, value: credentials.password);
      case M3uLogin(:final url, :final epgUrl):
        await _storage.write(key: _m3uUrlKey, value: url);
        if (epgUrl != null) await _storage.write(key: _m3uEpgUrlKey, value: epgUrl);
    }
  }

  Future<LoginConfig?> load() async {
    final m3uUrl = await _storage.read(key: _m3uUrlKey);
    if (m3uUrl != null) {
      return M3uLogin(url: m3uUrl, epgUrl: await _storage.read(key: _m3uEpgUrlKey));
    }

    final host = await _storage.read(key: _hostKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (host != null && username != null && password != null) {
      return XtreamLogin(XtreamCredentials(host: host, username: username, password: password));
    }

    return _migrateFromSharedPreferences();
  }

  Future<void> clear() async {
    for (final key in [_hostKey, _usernameKey, _passwordKey, _m3uUrlKey, _m3uEpgUrlKey]) {
      await _storage.delete(key: key);
    }
  }

  // Older versions of this app stored credentials in plaintext via
  // shared_preferences. Move them into secure storage the first time we find
  // them, then wipe the plaintext copy, so existing installs don't get
  // silently logged out.
  Future<LoginConfig?> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);
    if (host == null || username == null || password == null) return null;

    final login = XtreamLogin(XtreamCredentials(host: host, username: username, password: password));
    await save(login);
    await prefs.remove(_hostKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    return login;
  }
}
