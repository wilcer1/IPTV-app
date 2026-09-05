class MediaItem {
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? epgChannelId;

  const MediaItem({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.epgChannelId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
        'epgChannelId': epgChannelId,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        name: json['name'] as String,
        streamUrl: json['streamUrl'] as String,
        logoUrl: json['logoUrl'] as String?,
        epgChannelId: json['epgChannelId'] as String?,
      );
}
