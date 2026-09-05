class SeriesSummary {
  final String seriesId;
  final String name;
  final String? coverUrl;

  const SeriesSummary({
    required this.seriesId,
    required this.name,
    this.coverUrl,
  });

  factory SeriesSummary.fromJson(Map<String, dynamic> json) {
    return SeriesSummary(
      seriesId: json['series_id'].toString(),
      name: json['name'] as String? ?? 'Unknown series',
      coverUrl: json['cover'] as String?,
    );
  }
}
