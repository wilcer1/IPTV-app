class XtreamCredentials {
  final String host;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.host,
    required this.username,
    required this.password,
  });

  /// Many Xtream providers hand out their login as an M3U link of the form
  /// `http://host:port/get.php?username=U&password=P&type=m3u_plus`. That link
  /// is really just the account in disguise, so recognise it and return the
  /// credentials; anything else (a plain playlist) returns null.
  static XtreamCredentials? tryFromPlaylistUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (!uri.path.endsWith('/get.php')) return null;

    final username = uri.queryParameters['username'];
    final password = uri.queryParameters['password'];
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return null;
    }

    final prefix = uri.path.substring(0, uri.path.length - '/get.php'.length);
    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return XtreamCredentials(host: '$origin$prefix', username: username, password: password);
  }

  Uri playerApiUri({String? action, Map<String, String>? extraParams}) {
    return Uri.parse('$host/player_api.php').replace(queryParameters: {
      'username': username,
      'password': password,
      'action': ?action,
      ...?extraParams,
    });
  }

  String liveStreamUrl(int streamId, {String extension = 'm3u8'}) {
    return '$host/live/$username/$password/$streamId.$extension';
  }

  String vodStreamUrl(int streamId, String extension) {
    return '$host/movie/$username/$password/$streamId.$extension';
  }

  String seriesEpisodeStreamUrl(int episodeId, String extension) {
    return '$host/series/$username/$password/$episodeId.$extension';
  }

  Uri xmltvUri() {
    return Uri.parse('$host/xmltv.php').replace(queryParameters: {
      'username': username,
      'password': password,
    });
  }
}
