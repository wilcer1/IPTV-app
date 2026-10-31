/// Deterministic 64-bit FNV-1a hash as hex. `String.hashCode` isn't stable
/// across runs, and we need ids that survive restarts without storing the
/// original text.
String fnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(64).toRadixString(16);
}

class MediaItem {
  /// Stable identity that never contains credentials, so it's safe to key
  /// watch progress on (unlike [streamUrl], which embeds the Xtream
  /// username/password).
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? epgChannelId;
  final bool isLive;

  // Set for series episodes, so history can group them under their show and
  // work out what comes next.
  final String? seriesId;
  final String? seriesTitle;
  final int? season;
  final int? episode;

  MediaItem({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.epgChannelId,
    this.isLive = false,
    String? id,
    this.seriesId,
    this.seriesTitle,
    this.season,
    this.episode,
  }) : id = id ?? 'url:${fnv1a(streamUrl)}';

  /// e.g. "S2 E5", or null for anything that isn't an episode.
  String? get episodeLabel {
    if (season == null && episode == null) return null;
    return [
      if (season != null) 'S$season',
      if (episode != null) 'E$episode',
    ].join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
        'epgChannelId': epgChannelId,
        'isLive': isLive,
        'seriesId': seriesId,
        'seriesTitle': seriesTitle,
        'season': season,
        'episode': episode,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String?,
        name: json['name'] as String,
        streamUrl: json['streamUrl'] as String,
        logoUrl: json['logoUrl'] as String?,
        epgChannelId: json['epgChannelId'] as String?,
        isLive: json['isLive'] as bool? ?? false,
        seriesId: json['seriesId'] as String?,
        seriesTitle: json['seriesTitle'] as String?,
        season: json['season'] as int?,
        episode: json['episode'] as int?,
      );
}
