import 'package:sqflite/sqflite.dart';
import '../models/author_model.dart';

/// Data access for the Author kind: the chapters of one module's book.
/// Every row is keyed by `module_ref`, so a module owns its chapters outright
/// and ON DELETE CASCADE removes them with it.
class AuthorDao {
  final Database db;
  AuthorDao(this.db);

  Future<List<ChapterModel>> getChapters(int moduleRef) async {
    final rows = await db.rawQuery(
      'SELECT * FROM book_chapter WHERE module_ref=? '
      'ORDER BY chapter_order, id',
      [moduleRef],
    );
    return rows.map(ChapterModel.fromMap).toList();
  }

  Future<ChapterModel?> getChapter(int id) async {
    final rows = await db.query('book_chapter', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ChapterModel.fromMap(rows.first);
  }

  /// Appends a chapter after the existing ones. Ordering is an explicit
  /// column rather than insertion order because chapters get reordered.
  Future<int> createChapter({
    required int moduleRef,
    required String name,
    String? label,
  }) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(chapter_order),-1)+1 AS next FROM book_chapter WHERE module_ref=?',
      [moduleRef],
    );
    final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
    return db.insert('book_chapter', {
      'module_ref': moduleRef,
      'name': name,
      'chapter_label': label,
      'chapter_order': nextOrder,
    });
  }

  Future<void> renameChapter(int id, String name, {String? label}) async {
    await db.rawUpdate(
      "UPDATE book_chapter SET name=?,chapter_label=?,update_at=datetime('now') WHERE id=?",
      [name, label, id],
    );
  }

  Future<void> updateChapterContent(int id, String? content) async {
    await db.rawUpdate(
      "UPDATE book_chapter SET chapter_content=?,update_at=datetime('now') WHERE id=?",
      [content, id],
    );
  }

  Future<void> deleteChapter(int id) async {
    await db.delete('book_chapter', where: 'id=?', whereArgs: [id]);
  }

  /// Rewrites chapter_order to match the given id order in one transaction,
  /// so a reorder is never observable half-applied.
  Future<void> reorderChapters(List<int> idsInOrder) async {
    await db.transaction((txn) async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await txn.rawUpdate(
          'UPDATE book_chapter SET chapter_order=? WHERE id=?',
          [i, idsInOrder[i]],
        );
      }
    });
  }
}
