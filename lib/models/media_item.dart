class MediaItem {
  final String name;
  final String streamUrl;
  final String? logoUrl;

  const MediaItem({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        name: json['name'] as String,
        streamUrl: json['streamUrl'] as String,
        logoUrl: json['logoUrl'] as String?,
      );
}
