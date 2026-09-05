import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/category.dart';
import '../models/media_item.dart';
import '../models/series_details.dart';
import '../models/series_summary.dart';
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

  Future<dynamic> _getJson(String action, [Map<String, String>? extraParams]) async {
    final response = await http.get(
      credentials.playerApiUri(action: action, extraParams: extraParams),
    );
    if (response.statusCode != 200) {
      throw XtreamApiException('Request failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

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

  Future<List<Category>> getLiveCategories() async {
    final data = await _getJson('get_live_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaItem>> getLiveStreams([String? categoryId]) async {
    final data = await _getJson(
      'get_live_streams',
      categoryId == null ? null : {'category_id': categoryId},
    ) as List<dynamic>;

    return data.map((e) {
      final json = e as Map<String, dynamic>;
      final streamId = int.parse(json['stream_id'].toString());
      final icon = json['stream_icon'] as String?;
      return MediaItem(
        name: json['name'] as String? ?? 'Unknown channel',
        streamUrl: credentials.liveStreamUrl(streamId),
        logoUrl: (icon == null || icon.isEmpty) ? null : icon,
      );
    }).toList();
  }

  Future<List<Category>> getVodCategories() async {
    final data = await _getJson('get_vod_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaItem>> getVodStreams([String? categoryId]) async {
    final data = await _getJson(
      'get_vod_streams',
      categoryId == null ? null : {'category_id': categoryId},
    ) as List<dynamic>;

    return data.map((e) {
      final json = e as Map<String, dynamic>;
      final streamId = int.parse(json['stream_id'].toString());
      final extension = json['container_extension'] as String? ?? 'mp4';
      final icon = json['stream_icon'] as String?;
      return MediaItem(
        name: json['name'] as String? ?? 'Unknown movie',
        streamUrl: credentials.vodStreamUrl(streamId, extension),
        logoUrl: (icon == null || icon.isEmpty) ? null : icon,
      );
    }).toList();
  }

  Future<List<Category>> getSeriesCategories() async {
    final data = await _getJson('get_series_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SeriesSummary>> getSeries([String? categoryId]) async {
    final data = await _getJson(
      'get_series',
      categoryId == null ? null : {'category_id': categoryId},
    ) as List<dynamic>;

    return data
        .map((e) => SeriesSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SeriesDetails> getSeriesInfo(String seriesId) async {
    final data = await _getJson('get_series_info', {'series_id': seriesId})
        as Map<String, dynamic>;

    final info = data['info'] as Map<String, dynamic>? ?? {};
    final episodesBySeason = data['episodes'] as Map<String, dynamic>? ?? {};

    final seasons = episodesBySeason.entries.map((entry) {
      final episodes = (entry.value as List<dynamic>).map((e) {
        final json = e as Map<String, dynamic>;
        final episodeId = int.parse(json['id'].toString());
        final extension =
            json['container_extension'] as String? ?? 'mp4';
        return MediaItem(
          name: json['title'] as String? ?? 'Episode',
          streamUrl: credentials.seriesEpisodeStreamUrl(episodeId, extension),
        );
      }).toList();
      return SeriesSeason(seasonNumber: entry.key, episodes: episodes);
    }).toList();

    return SeriesDetails(
      name: info['name'] as String? ?? 'Unknown series',
      coverUrl: info['cover'] as String?,
      plot: info['plot'] as String?,
      seasons: seasons,
    );
  }
}
