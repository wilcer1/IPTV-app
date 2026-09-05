class XtreamCredentials {
  final String host;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.host,
    required this.username,
    required this.password,
  });

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
}
