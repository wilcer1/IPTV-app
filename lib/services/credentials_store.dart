import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/xtream_credentials.dart';

class CredentialsStore {
  static const _hostKey = 'xtream_host';
  static const _usernameKey = 'xtream_username';
  static const _passwordKey = 'xtream_password';

  static const _storage = FlutterSecureStorage();

  Future<void> save(XtreamCredentials credentials) async {
    await _storage.write(key: _hostKey, value: credentials.host);
    await _storage.write(key: _usernameKey, value: credentials.username);
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  Future<XtreamCredentials?> load() async {
    final host = await _storage.read(key: _hostKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (host != null && username != null && password != null) {
      return XtreamCredentials(host: host, username: username, password: password);
    }

    return _migrateFromSharedPreferences();
  }

  Future<void> clear() async {
    await _storage.delete(key: _hostKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }

  // Older versions of this app stored credentials in plaintext via
  // shared_preferences. Move them into secure storage the first time we find
  // them, then wipe the plaintext copy, so existing installs don't get
  // silently logged out.
  Future<XtreamCredentials?> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);
    if (host == null || username == null || password == null) return null;

    final credentials = XtreamCredentials(host: host, username: username, password: password);
    await save(credentials);
    await prefs.remove(_hostKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    return credentials;
  }
}
