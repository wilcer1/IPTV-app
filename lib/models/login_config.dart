import 'xtream_credentials.dart';

/// What a signed-in user is connected to: either an Xtream Codes account or a
/// plain M3U playlist URL.
sealed class LoginConfig {
  const LoginConfig();

  Map<String, dynamic> toJson();

  factory LoginConfig.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'm3u') {
      return M3uLogin(
        url: json['url'] as String,
        epgUrl: json['epgUrl'] as String?,
      );
    }
    // Payloads from before M3U support carry no "type" and are always Xtream.
    return XtreamLogin(
      XtreamCredentials(
        host: json['host'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      ),
    );
  }
}

class XtreamLogin extends LoginConfig {
  final XtreamCredentials credentials;

  const XtreamLogin(this.credentials);

  // host/username/password stay top-level so a device still running a
  // pre-M3U version can pair with this one.
  @override
  Map<String, dynamic> toJson() => {
        'type': 'xtream',
        'host': credentials.host,
        'username': credentials.username,
        'password': credentials.password,
      };
}

class M3uLogin extends LoginConfig {
  final String url;
  final String? epgUrl;

  const M3uLogin({required this.url, this.epgUrl});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'm3u',
        'url': url,
        'epgUrl': epgUrl,
      };
}
