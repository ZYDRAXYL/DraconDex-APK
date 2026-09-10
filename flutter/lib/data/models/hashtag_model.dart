class HashtagModel {
  final int id;
  final String name;
  final int? colorId;
  final String? colorCode;
  final String updatedAt;

  const HashtagModel({
    required this.id,
    required this.name,
    this.colorId,
    this.colorCode,
    required this.updatedAt,
  });

  factory HashtagModel.fromMap(Map<String, dynamic> m) => HashtagModel(
        id: m['id'] as int,
        name: m['tag_name'] as String,
        colorId: m['tag_color'] as int?,
        colorCode: m['color_code'] as String?,
        updatedAt: m['update_at'] as String? ?? '',
      );
}
