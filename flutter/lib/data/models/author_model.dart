// Author-kind content model: a module's book chapters (`book_chapter`, keyed
// by module_ref). The Electron counterpart is src/renderer/mod/author.js —
// same table, so a vault written by either app opens in the other.

class ChapterModel {
  final int id;
  final int moduleRef;
  final String name;
  final String? label;
  final String? content;
  final int order;
  final String updatedAt;

  const ChapterModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.label,
    this.content,
    this.order = 0,
    this.updatedAt = '',
  });

  factory ChapterModel.fromMap(Map<String, dynamic> m) => ChapterModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        label: m['chapter_label'] as String?,
        content: m['chapter_content'] as String?,
        order: m['chapter_order'] as int? ?? 0,
        updatedAt: m['update_at'] as String? ?? '',
      );
}
