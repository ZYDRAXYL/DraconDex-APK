class ColorModel {
  final int id;
  final String colorCode;
  final String updatedAt;

  const ColorModel({required this.id, required this.colorCode, required this.updatedAt});

  factory ColorModel.fromMap(Map<String, dynamic> m) => ColorModel(
        id: m['id'] as int,
        colorCode: m['color_code'] as String,
        updatedAt: m['update_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'id': id, 'color_code': colorCode, 'update_at': updatedAt};
}
