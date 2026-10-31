import '../models/login_config.dart';
import 'iptv_client.dart';
import 'm3u_client.dart';
import 'xtream_api_client.dart';

IptvClient createClient(LoginConfig login) {
  return switch (login) {
    XtreamLogin(:final credentials) => XtreamApiClient(credentials),
    M3uLogin() => M3uClient(login),
  };
}
