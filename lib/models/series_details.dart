import 'media_item.dart';

class SeriesSeason {
  final String seasonNumber;
  final List<MediaItem> episodes;

  const SeriesSeason({required this.seasonNumber, required this.episodes});
}

class SeriesDetails {
  final String name;
  final String? coverUrl;
  final String? plot;
  final List<SeriesSeason> seasons;

  const SeriesDetails({
    required this.name,
    this.coverUrl,
    this.plot,
    required this.seasons,
  });
}
