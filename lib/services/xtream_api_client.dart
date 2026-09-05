import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/live_category.dart';
import '../models/xtream_credentials.dart';

class XtreamApiException implements Exception {
  final String message;
  XtreamApiException(this.message);

  @override
  String toString() => message;
}

class XtreamApiClient {
  final XtreamCredentials credentials;

  const XtreamApiClient(this.credentials);

  Future<void> authenticate() async {
    final response = await http.get(credentials.playerApiUri());
    if (response.statusCode != 200) {
      throw XtreamApiException('Server returned HTTP ${response.statusCode}');
    }

    final dynamic data = jsonDecode(response.body);
    final userInfo = data is Map<String, dynamic> ? data['user_info'] : null;
    if (userInfo is! Map<String, dynamic> || userInfo['auth'] != 1) {
      throw XtreamApiException('Invalid host, username, or password');
    }
  }

  Future<List<LiveCategory>> getLiveCategories() async {
    final response = await http.get(
      credentials.playerApiUri(action: 'get_live_categories'),
    );
    if (response.statusCode != 200) {
      throw XtreamApiException(
          'Failed to load categories (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => LiveCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Channel>> getLiveStreams([String? categoryId]) async {
    final response = await http.get(
      credentials.playerApiUri(
        action: 'get_live_streams',
        extraParams: categoryId == null ? null : {'category_id': categoryId},
      ),
    );
    if (response.statusCode != 200) {
      throw XtreamApiException(
          'Failed to load channels (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) {
      final json = e as Map<String, dynamic>;
      final streamId = int.parse(json['stream_id'].toString());
      final icon = json['stream_icon'] as String?;
      return Channel(
        name: json['name'] as String? ?? 'Unknown channel',
        streamUrl: credentials.liveStreamUrl(streamId),
        logoUrl: (icon == null || icon.isEmpty) ? null : icon,
      );
    }).toList();
  }
}
