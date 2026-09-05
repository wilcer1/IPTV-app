class LiveCategory {
  final String id;
  final String name;

  const LiveCategory({required this.id, required this.name});

  factory LiveCategory.fromJson(Map<String, dynamic> json) {
    return LiveCategory(
      id: json['category_id'].toString(),
      name: json['category_name'] as String? ?? 'Unknown',
    );
  }
}
