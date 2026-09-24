import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';
import '../models/sketcher_model.dart';
import 'page_block_dao.dart';

/// Data access for the Sketcher kind: a module's drawing pages and strokes.
///
/// sketch_pin rows are deliberately untouched. A pin links a point on the
/// page to another entity, which needs the entity picker the desktop has;
/// leaving them alone keeps existing pins intact rather than half-supporting
/// them from here.
class SketcherDao {
  final Database db;
  SketcherDao(this.db);

  Future<List<SketchPageModel>> getPages(int moduleRef) async {
    final rows = await db.query('sketch_page',
        where: 'module_ref=?', whereArgs: [moduleRef], orderBy: 'page_order, id');
    return rows.map(SketchPageModel.fromMap).toList();
  }

  Future<int> createPage({required int moduleRef, required String name}) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(page_order),-1)+1 AS next FROM sketch_page WHERE module_ref=?',
      [moduleRef],
    );
    final id = await db.insert('sketch_page', {
      'module_ref': moduleRef,
      'name': name,
      'page_order': Sqflite.firstIntValue(orderRows) ?? 0,
    });
    await WikiService.resolveDangling(db, name, await WikiService.nexusOfModule(db, moduleRef));
    return id;
  }

  Future<void> renamePage(int id, String name) async {
    final old = await db.rawQuery(
        'SELECT p.name, m.nexus_ref FROM sketch_page p JOIN module m ON p.module_ref=m.id WHERE p.id=?', [id]);
    await db.rawUpdate("UPDATE sketch_page SET name=?,update_at=datetime('now') WHERE id=?", [name, id]);
    if (old.isNotEmpty) {
      await WikiService.renamed(db, 'skpg_$id', old.first['name'] as String?, name, old.first['nexus_ref'] as int?);
    }
  }

  /// Rewrites page_order to [idsInOrder] in one transaction.
  Future<void> reorderPages(List<int> idsInOrder) async {
    await db.transaction((txn) async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await txn.rawUpdate('UPDATE sketch_page SET page_order=? WHERE id=?', [i, idsInOrder[i]]);
      }
    });
  }

  Future<void> deletePage(int id) async {
    await PageBlockDao(db).clearItem('skpg_$id'); // its page goes with it (EXE clearItemBlocks)
    await db.delete('sketch_page', where: 'id=?', whereArgs: [id]);
  }

  Future<List<SketchStrokeModel>> getStrokes(int pageRef) async {
    final rows = await db.query('sketch_stroke',
        where: 'page_ref=?', whereArgs: [pageRef], orderBy: 'id');
    return rows.map(SketchStrokeModel.fromMap).toList();
  }

  Future<int> addStroke({
    required int pageRef,
    required String color,
    required double width,
    required List<double> points,
  }) async {
    return db.insert('sketch_stroke', {
      'page_ref': pageRef,
      'color': color,
      'width': width,
      'points': encodeStrokePoints(points),
    });
  }

  Future<void> deleteStroke(int id) async {
    await db.delete('sketch_stroke', where: 'id=?', whereArgs: [id]);
  }

  /// The most recent stroke on a page, for undo. Ordering by id rather than
  /// create_at because two strokes drawn in the same second would otherwise
  /// be indistinguishable.
  Future<int?> lastStrokeId(int pageRef) async {
    final rows = await db.query('sketch_stroke',
        columns: ['id'], where: 'page_ref=?', whereArgs: [pageRef],
        orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<void> clearPage(int pageRef) async {
    await db.delete('sketch_stroke', where: 'page_ref=?', whereArgs: [pageRef]);
  }
}
