import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

import '../models/account_info.dart';
import '../models/category.dart';
import '../models/epg_program.dart';
import '../models/login_config.dart';
import '../models/media_item.dart';
import '../models/series_details.dart';
import '../models/series_summary.dart';
import '../models/xtream_credentials.dart';
import 'iptv_client.dart';
import 'xmltv_parser.dart';

class XtreamApiException implements Exception {
  final String message;
  XtreamApiException(this.message);

  @override
  String toString() => message;
}

class XtreamApiClient implements IptvClient {
  final XtreamCredentials credentials;

  const XtreamApiClient(this.credentials);

  @override
  LoginConfig get login => XtreamLogin(credentials);

  @override
  String get accountTitle => credentials.username;

  @override
  String get accountSubtitle => credentials.host;

  Future<dynamic> _getJson(String action, [Map<String, String>? extraParams]) async {
    final response = await http.get(
      credentials.playerApiUri(action: action, extraParams: extraParams),
    );
    if (response.statusCode != 200) {
      throw XtreamApiException('Request failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> _fetchUserInfo() async {
    final response = await http.get(credentials.playerApiUri());
    if (response.statusCode != 200) {
      throw XtreamApiException('Server returned HTTP ${response.statusCode}');
    }

    final dynamic data = jsonDecode(response.body);
    final userInfo = data is Map<String, dynamic> ? data['user_info'] : null;
    if (userInfo is! Map<String, dynamic> || userInfo['auth'] != 1) {
      throw XtreamApiException('Invalid host, username, or password');
    }
    return userInfo;
  }

  @override
  Future<void> authenticate() async {
    await _fetchUserInfo();
  }

  @override
  Future<AccountInfo> getAccountInfo() async {
    return AccountInfo.fromJson(await _fetchUserInfo());
  }

  @override
  Future<List<Category>> getLiveCategories() async {
    final data = await _getJson('get_live_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MediaItem>> getLiveStreams([String? categoryId]) async {
    final data = await _getJson(
      'get_live_streams',
      categoryId == null ? null : {'category_id': categoryId},
    ) as List<dynamic>;

    return data.map((e) {
      final json = e as Map<String, dynamic>;
      final streamId = int.parse(json['stream_id'].toString());
      final icon = json['stream_icon'] as String?;
      final epgChannelId = json['epg_channel_id'] as String?;
      return MediaItem(
        id: 'x:live:$streamId',
        name: json['name'] as String? ?? 'Unknown channel',
        streamUrl: credentials.liveStreamUrl(streamId),
        logoUrl: (icon == null || icon.isEmpty) ? null : icon,
        epgChannelId: (epgChannelId == null || epgChannelId.isEmpty)
            ? null
            : epgChannelId,
        isLive: true,
      );
    }).toList();
  }

  @override
  Future<List<EpgProgram>> getFullEpg() async {
    final response = await http.get(credentials.xmltvUri());
    if (response.statusCode != 200) {
      throw XtreamApiException('Failed to load EPG (HTTP ${response.statusCode})');
    }
    return compute(parseXmltvBytes, response.bodyBytes);
  }

  @override
  Future<List<Category>> getVodCategories() async {
    final data = await _getJson('get_vod_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
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
        id: 'x:movie:$streamId',
        name: json['name'] as String? ?? 'Unknown movie',
        streamUrl: credentials.vodStreamUrl(streamId, extension),
        logoUrl: (icon == null || icon.isEmpty) ? null : icon,
      );
    }).toList();
  }

  @override
  Future<List<Category>> getSeriesCategories() async {
    final data = await _getJson('get_series_categories') as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<SeriesSummary>> getSeries([String? categoryId]) async {
    final data = await _getJson(
      'get_series',
      categoryId == null ? null : {'category_id': categoryId},
    ) as List<dynamic>;

    return data
        .map((e) => SeriesSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SeriesDetails> getSeriesInfo(String seriesId) async {
    final data = await _getJson('get_series_info', {'series_id': seriesId})
        as Map<String, dynamic>;

    final info = data['info'] as Map<String, dynamic>? ?? {};
    final episodesBySeason = data['episodes'] as Map<String, dynamic>? ?? {};
    final seriesName = info['name'] as String? ?? 'Unknown series';
    final cover = info['cover'] as String?;

    final seasonEntries = episodesBySeason.entries.toList()
      ..sort((a, b) => (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0));

    final seasons = seasonEntries.map((entry) {
      final seasonNumber = int.tryParse(entry.key);
      final episodes = (entry.value as List<dynamic>).map((e) {
        final json = e as Map<String, dynamic>;
        final episodeId = int.parse(json['id'].toString());
        final extension =
            json['container_extension'] as String? ?? 'mp4';
        final episodeInfo = json['info'] as Map<String, dynamic>?;
        final thumb = episodeInfo?['movie_image'] as String?;
        return MediaItem(
          id: 'x:ep:$episodeId',
          name: json['title'] as String? ?? 'Episode',
          streamUrl: credentials.seriesEpisodeStreamUrl(episodeId, extension),
          logoUrl: (thumb != null && thumb.isNotEmpty) ? thumb : cover,
          seriesId: seriesId,
          seriesTitle: seriesName,
          season: seasonNumber,
          episode: int.tryParse('${json['episode_num']}'),
        );
      }).toList();
      return SeriesSeason(seasonNumber: entry.key, episodes: episodes);
    }).toList();

    return SeriesDetails(
      name: seriesName,
      coverUrl: cover,
      plot: info['plot'] as String?,
      seasons: seasons,
    );
  }
}
