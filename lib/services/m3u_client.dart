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
import 'iptv_client.dart';
import 'm3u_parser.dart';
import 'xmltv_parser.dart';

class M3uException implements Exception {
  final String message;
  M3uException(this.message);

  @override
  String toString() => message;
}

/// Serves a plain M3U playlist through the same interface as an Xtream
/// account. The playlist is downloaded and parsed once (off the UI thread —
/// they can be tens of megabytes) and every call afterwards reads from that.
class M3uClient implements IptvClient {
  final M3uLogin config;

  M3uClient(this.config);

  Future<M3uLibrary>? _library;

  @override
  LoginConfig get login => config;

  @override
  String get accountTitle => 'M3U playlist';

  // Only the host: playlist URLs routinely carry a token or password.
  @override
  String get accountSubtitle => Uri.tryParse(config.url)?.host ?? '';

  Future<M3uLibrary> _load() {
    return _library ??= _download().catchError((Object e) {
      _library = null; // allow a retry instead of caching the failure
      throw e;
    });
  }

  Future<M3uLibrary> _download() async {
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(config.url))
          .timeout(const Duration(minutes: 3));
    } catch (e) {
      throw M3uException('Could not download the playlist: $e');
    }
    if (response.statusCode != 200) {
      throw M3uException('Playlist request failed (HTTP ${response.statusCode})');
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final library = await compute(buildM3uLibrary, text);
    if (library.entryCount == 0) {
      throw M3uException('No channels found — is this really an M3U playlist link?');
    }
    return library;
  }

  @override
  Future<void> authenticate() async {
    await _load();
  }

  @override
  Future<AccountInfo?> getAccountInfo() async => null;

  @override
  Future<List<Category>> getLiveCategories() async => (await _load()).liveCategories;

  @override
  Future<List<MediaItem>> getLiveStreams([String? categoryId]) async {
    final library = await _load();
    return _select(library.liveByCategory, categoryId);
  }

  @override
  Future<List<Category>> getVodCategories() async => (await _load()).vodCategories;

  @override
  Future<List<MediaItem>> getVodStreams([String? categoryId]) async {
    final library = await _load();
    return _select(library.vodByCategory, categoryId);
  }

  @override
  Future<List<Category>> getSeriesCategories() async => (await _load()).seriesCategories;

  @override
  Future<List<SeriesSummary>> getSeries([String? categoryId]) async {
    final library = await _load();
    return _select(library.seriesByCategory, categoryId);
  }

  @override
  Future<SeriesDetails> getSeriesInfo(String seriesId) async {
    final details = (await _load()).seriesDetails[seriesId];
    if (details == null) throw M3uException('Series not found in this playlist.');
    return details;
  }

  @override
  Future<List<EpgProgram>> getFullEpg() async {
    final epgUrl = config.epgUrl ?? (await _load()).epgUrl;
    if (epgUrl == null || epgUrl.isEmpty) return const [];

    final response = await http.get(Uri.parse(epgUrl)).timeout(const Duration(minutes: 3));
    if (response.statusCode != 200) {
      throw M3uException('Failed to load EPG (HTTP ${response.statusCode})');
    }
    return compute(parseXmltvBytes, response.bodyBytes);
  }

  List<T> _select<T>(Map<String, List<T>> byCategory, String? categoryId) {
    if (categoryId == null) return [for (final list in byCategory.values) ...list];
    return byCategory[categoryId] ?? const [];
  }
}
