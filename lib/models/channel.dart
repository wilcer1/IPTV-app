class Channel {
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? group;

  const Channel({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.group,
  });
}
