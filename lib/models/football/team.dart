String normalizeTeamText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\b(fc|cf|afc|sc|ac)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class Team {
  final int id;
  final String name;
  final String? shortName;
  final String? tla;
  final String? crestUrl;

  const Team({
    required this.id,
    required this.name,
    this.shortName,
    this.tla,
    this.crestUrl,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown team',
      shortName: json['shortName'] as String?,
      tla: json['tla'] as String?,
      crestUrl: json['crest'] as String?,
    );
  }

  /// Name variants worth matching against EPG program titles, normalized to
  /// lowercase with common club suffixes stripped (providers rarely include
  /// "FC"/"CF" in program titles).
  List<String> get searchAliases {
    final raw = <String?>{name, shortName, tla}.whereType<String>();
    return raw.map(normalizeTeamText).where((a) => a.length >= 3).toSet().toList();
  }
}
