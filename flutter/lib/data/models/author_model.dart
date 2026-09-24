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

  /// The corkboard card (V5.md §11.6): a synopsis, where the chapter stands
  /// (idea/draft/revised/done), and whose point of view it is told from.
  final String? synopsis;
  final String? status;
  final String? povKey;

  const ChapterModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.label,
    this.content,
    this.order = 0,
    this.updatedAt = '',
    this.synopsis,
    this.status,
    this.povKey,
  });

  factory ChapterModel.fromMap(Map<String, dynamic> m) => ChapterModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        label: m['chapter_label'] as String?,
        content: m['chapter_content'] as String?,
        order: m['chapter_order'] as int? ?? 0,
        updatedAt: m['update_at'] as String? ?? '',
        synopsis: m['synopsis'] as String?,
        status: m['status'] as String?,
        povKey: m['pov_key'] as String?,
      );
}
