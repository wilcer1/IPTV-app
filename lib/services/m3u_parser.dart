import 'dart:convert';

import '../models/category.dart';
import '../models/media_item.dart';
import '../models/series_details.dart';
import '../models/series_summary.dart';

const _uncategorized = 'Uncategorized';

class M3uEntry {
  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;

  const M3uEntry({
    required this.name,
    required this.url,
    required this.group,
    this.logo,
    this.tvgId,
  });
}

class ParsedPlaylist {
  final List<M3uEntry> entries;
  final String? epgUrl;

  const ParsedPlaylist({required this.entries, this.epgUrl});
}

final _attributeRegex = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

ParsedPlaylist parseM3u(String content) {
  final entries = <M3uEntry>[];
  String? epgUrl;

  String? pendingName;
  Map<String, String> pendingAttributes = const {};
  String? pendingGroupFallback;

  final text = content.startsWith('﻿') ? content.substring(1) : content;
  for (final rawLine in const LineSplitter().convert(text)) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTM3U')) {
      final attributes = _attributes(line);
      final raw = attributes['url-tvg'] ?? attributes['x-tvg-url'] ?? attributes['tvg-url'];
      if (raw != null && raw.trim().isNotEmpty) {
        epgUrl = raw.split(',').first.trim();
      }
    } else if (line.startsWith('#EXTINF')) {
      pendingAttributes = _attributes(line);
      pendingName = _titleOf(line, pendingAttributes);
    } else if (line.startsWith('#EXTGRP:')) {
      pendingGroupFallback = line.substring('#EXTGRP:'.length).trim();
    } else if (!line.startsWith('#')) {
      if (pendingName != null) {
        final group = (pendingAttributes['group-title'] ?? '').trim();
        final logo = pendingAttributes['tvg-logo'];
        final tvgId = pendingAttributes['tvg-id'];
        entries.add(M3uEntry(
          name: pendingName,
          url: line,
          group: group.isNotEmpty
              ? group
              : ((pendingGroupFallback ?? '').isNotEmpty ? pendingGroupFallback! : _uncategorized),
          logo: (logo == null || logo.isEmpty) ? null : logo,
          tvgId: (tvgId == null || tvgId.isEmpty) ? null : tvgId,
        ));
      }
      pendingName = null;
      pendingAttributes = const {};
      pendingGroupFallback = null;
    }
  }

  return ParsedPlaylist(entries: entries, epgUrl: epgUrl);
}

Map<String, String> _attributes(String line) {
  return {
    for (final match in _attributeRegex.allMatches(line))
      match.group(1)!.toLowerCase(): match.group(2)!,
  };
}

// The display name follows the first comma after the last attribute — not
// just the first comma on the line, because attribute values such as
// group-title="News, Sports" can contain commas themselves.
String _titleOf(String line, Map<String, String> attributes) {
  var searchFrom = 0;
  for (final match in _attributeRegex.allMatches(line)) {
    searchFrom = match.end;
  }
  final comma = line.indexOf(',', searchFrom);
  final title = comma == -1 ? '' : line.substring(comma + 1).trim();
  if (title.isNotEmpty) return title;
  return attributes['tvg-name'] ?? 'Unknown channel';
}

enum _Kind { live, movie, series }

final _vodExtensionRegex = RegExp(r'\.(mp4|mkv|avi|mov|wmv|flv|m4v)$');
final _episodeRegex = RegExp(r'^(.*?)[\s._\-:]*[Ss](\d{1,3})\s*[Ee](\d{1,4})');

_Kind _kindOf(M3uEntry entry) {
  final path = (Uri.tryParse(entry.url)?.path ?? entry.url).toLowerCase();
  if (path.contains('/series/')) return _Kind.series;
  if (path.contains('/movie/')) return _Kind.movie;
  if (path.contains('/live/')) return _Kind.live;
  if (_episodeRegex.hasMatch(entry.name)) return _Kind.series;
  if (_vodExtensionRegex.hasMatch(path)) return _Kind.movie;
  return _Kind.live;
}

/// A playlist sorted into the same shape the Xtream API gives us, so the rest
/// of the app doesn't care where the data came from.
class M3uLibrary {
  final List<Category> liveCategories;
  final Map<String, List<MediaItem>> liveByCategory;
  final List<Category> vodCategories;
  final Map<String, List<MediaItem>> vodByCategory;
  final List<Category> seriesCategories;
  final Map<String, List<SeriesSummary>> seriesByCategory;
  final Map<String, SeriesDetails> seriesDetails;
  final String? epgUrl;
  final int entryCount;

  const M3uLibrary({
    required this.liveCategories,
    required this.liveByCategory,
    required this.vodCategories,
    required this.vodByCategory,
    required this.seriesCategories,
    required this.seriesByCategory,
    required this.seriesDetails,
    required this.epgUrl,
    required this.entryCount,
  });
}

M3uLibrary buildM3uLibrary(String content) {
  final playlist = parseM3u(content);

  final liveByCategory = <String, List<MediaItem>>{};
  final vodByCategory = <String, List<MediaItem>>{};
  // category -> series key -> episodes, keeping playlist order throughout.
  final seriesBuckets = <String, Map<String, _SeriesBucket>>{};

  for (final entry in playlist.entries) {
    switch (_kindOf(entry)) {
      case _Kind.live:
        (liveByCategory[entry.group] ??= []).add(MediaItem(
          name: entry.name,
          streamUrl: entry.url,
          logoUrl: entry.logo,
          epgChannelId: entry.tvgId,
          isLive: true,
        ));
      case _Kind.movie:
        (vodByCategory[entry.group] ??= []).add(MediaItem(
          name: entry.name,
          streamUrl: entry.url,
          logoUrl: entry.logo,
        ));
      case _Kind.series:
        final match = _episodeRegex.firstMatch(entry.name);
        var title = (match?.group(1) ?? '').trim();
        if (title.isEmpty) title = entry.group;
        final season = int.tryParse(match?.group(2) ?? '') ?? 1;
        final episodeNumber = int.tryParse(match?.group(3) ?? '');
        final seriesKey = '${entry.group}|${title.toLowerCase()}';
        final bucket = (seriesBuckets[entry.group] ??= {})
            .putIfAbsent(seriesKey, () => _SeriesBucket(seriesKey, title, entry.logo));
        (bucket.seasons[season] ??= []).add(MediaItem(
          name: entry.name,
          streamUrl: entry.url,
          logoUrl: entry.logo ?? bucket.cover,
          seriesId: bucket.id,
          seriesTitle: bucket.title,
          season: season,
          episode: episodeNumber,
        ));
    }
  }

  final seriesByCategory = <String, List<SeriesSummary>>{};
  final seriesDetails = <String, SeriesDetails>{};
  seriesBuckets.forEach((category, buckets) {
    for (final bucket in buckets.values) {
      (seriesByCategory[category] ??= [])
          .add(SeriesSummary(seriesId: bucket.id, name: bucket.title, coverUrl: bucket.cover));
      final seasonNumbers = bucket.seasons.keys.toList()..sort();
      seriesDetails[bucket.id] = SeriesDetails(
        name: bucket.title,
        coverUrl: bucket.cover,
        seasons: [
          for (final n in seasonNumbers)
            SeriesSeason(
              seasonNumber: '$n',
              // Playlists are often shuffled; episodes must be in watching
              // order for "next episode" to mean anything. Dart's sort isn't
              // stable, so tie-break on the original position.
              episodes: _sortedByEpisode(bucket.seasons[n]!),
            ),
        ],
      );
    }
  });

  List<Category> categoriesOf(Iterable<String> names) =>
      [for (final name in names) Category(id: name, name: name)];

  return M3uLibrary(
    liveCategories: categoriesOf(liveByCategory.keys),
    liveByCategory: liveByCategory,
    vodCategories: categoriesOf(vodByCategory.keys),
    vodByCategory: vodByCategory,
    seriesCategories: categoriesOf(seriesByCategory.keys),
    seriesByCategory: seriesByCategory,
    seriesDetails: seriesDetails,
    epgUrl: playlist.epgUrl,
    entryCount: playlist.entries.length,
  );
}

List<MediaItem> _sortedByEpisode(List<MediaItem> episodes) {
  final indexed = [for (var i = 0; i < episodes.length; i++) (i, episodes[i])];
  indexed.sort((a, b) {
    final byEpisode = (a.$2.episode ?? 1 << 30).compareTo(b.$2.episode ?? 1 << 30);
    return byEpisode != 0 ? byEpisode : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

class _SeriesBucket {
  final String id;
  final String title;
  final String? cover;
  final Map<int, List<MediaItem>> seasons = {};

  _SeriesBucket(this.id, this.title, this.cover);
}
