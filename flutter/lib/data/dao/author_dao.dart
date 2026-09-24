import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';
import '../models/author_model.dart';
import 'page_block_dao.dart';

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
    final id = await db.insert('book_chapter', {
      'module_ref': moduleRef,
      'name': name,
      'chapter_label': label,
      'chapter_order': nextOrder,
    });
    await WikiService.resolveDangling(db, name, await WikiService.nexusOfModule(db, moduleRef));
    return id;
  }

  Future<void> renameChapter(int id, String name, {String? label}) async {
    final old = await db.rawQuery(
        'SELECT ch.name, m.nexus_ref FROM book_chapter ch JOIN module m ON ch.module_ref=m.id WHERE ch.id=?', [id]);
    await db.rawUpdate(
      "UPDATE book_chapter SET name=?,chapter_label=?,update_at=datetime('now') WHERE id=?",
      [name, label, id],
    );
    if (old.isNotEmpty) {
      await WikiService.renamed(db, 'bchp_$id', old.first['name'] as String?, name, old.first['nexus_ref'] as int?);
    }
  }

  Future<void> updateChapterContent(int id, String? content) async {
    await db.rawUpdate(
      "UPDATE book_chapter SET chapter_content=?,update_at=datetime('now') WHERE id=?",
      [content, id],
    );
    await WikiService.reindexSource(db, 'bchp', id);
  }

  /// The corkboard's facts, one or more at a time (EXE setChapterMeta).
  Future<void> setChapterMeta(int id, {String? synopsis, String? status, String? povKey, bool clearPov = false}) async {
    final set = <String, Object?>{
      'synopsis': ?synopsis,
      if (status != null) 'status': status.isEmpty ? null : status,
      if (povKey != null || clearPov) 'pov_key': povKey,
    };
    if (set.isEmpty) return;
    await db.rawUpdate(
      "UPDATE book_chapter SET ${set.keys.map((k) => '$k=?').join(',')},update_at=datetime('now') WHERE id=?",
      [...set.values, id],
    );
  }

  Future<void> deleteChapter(int id) async {
    await PageBlockDao(db).clearItem('bchp_$id'); // its page goes with it (EXE clearItemBlocks)
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
