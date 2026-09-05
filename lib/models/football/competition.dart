class Competition {
  final int id;
  final String name;
  final String code;
  final String? emblemUrl;

  const Competition({
    required this.id,
    required this.name,
    required this.code,
    this.emblemUrl,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown competition',
      code: json['code'] as String? ?? '',
      emblemUrl: json['emblem'] as String?,
    );
  }
}
