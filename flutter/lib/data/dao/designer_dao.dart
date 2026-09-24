import 'package:sqflite/sqflite.dart';
import '../models/designer_model.dart';

/// Data access for the Designer kind: the nodes on a module's board and the
/// edges between them.
class DesignerDao {
  final Database db;
  DesignerDao(this.db);

  Future<List<DesignNodeModel>> getNodes(int moduleRef) async {
    final rows = await db.query('design_node',
        where: 'module_ref=?', whereArgs: [moduleRef], orderBy: 'id');
    return rows.map(DesignNodeModel.fromMap).toList();
  }

  Future<int> createNode({
    required int moduleRef,
    required double x,
    required double y,
    String shape = 'box',
    String? text,
  }) async {
    return db.insert('design_node', {
      'module_ref': moduleRef,
      'shape': shape,
      'x': x,
      'y': y,
      'node_text': text,
    });
  }

  /// Position only — called on every drag end, so it deliberately does not
  /// touch the text or shape a concurrent edit may have changed.
  Future<void> moveNode(int id, double x, double y) async {
    await db.rawUpdate(
      "UPDATE design_node SET x=?,y=?,update_at=datetime('now') WHERE id=?",
      [x, y, id],
    );
  }

  /// A comic panel or balloon dragged by its corner grip (EXE resizeNode).
  Future<void> resizeNode(int id, double w, double h) async {
    await db.rawUpdate("UPDATE design_node SET w=?,h=?,update_at=datetime('now') WHERE id=?", [w, h, id]);
  }

  Future<void> updateNode(int id, {String? text, String? shape}) async {
    await db.rawUpdate(
      "UPDATE design_node SET node_text=?,shape=?,update_at=datetime('now') WHERE id=?",
      [text, shape ?? 'box', id],
    );
  }

  Future<void> setLinker(int id, String? key) async {
    await db.rawUpdate("UPDATE design_node SET linker_key=?,update_at=datetime('now') WHERE id=?", [key, id]);
  }

  /// "Number by position" (EXE renumberDesignReadOrder): panels and
  /// balloons in rows — a node starting above the middle of the row's first
  /// node joins that row — rows top to bottom, each left to right.
  Future<void> renumberReadOrder(int moduleRef) async {
    final rows = [
      ...await db.rawQuery(
          "SELECT id, x, y, COALESCE(h, 120) AS h FROM design_node WHERE module_ref=? AND shape IN ('panel','balloon')",
          [moduleRef]),
    ]..sort((a, b) => (a['y'] as num).compareTo(b['y'] as num));
    final bands = <(num, num, List<Map<String, Object?>>)>[];
    for (final r in rows) {
      final y = r['y'] as num;
      final band = bands.where((b) => y < b.$1 + b.$2 / 2).firstOrNull;
      if (band != null) {
        band.$3.add(r);
      } else {
        bands.add((y, r['h'] as num, [r]));
      }
    }
    var n = 0;
    await db.transaction((txn) async {
      for (final b in bands) {
        b.$3.sort((a, c) => (a['x'] as num).compareTo(c['x'] as num));
        for (final r in b.$3) {
          await txn.rawUpdate('UPDATE design_node SET read_order=? WHERE id=?', [++n, r['id']]);
        }
      }
    });
  }

  /// design_edge references design_node ON DELETE CASCADE, so removing a node
  /// takes its edges with it.
  Future<void> deleteNode(int id) async {
    await db.delete('design_node', where: 'id=?', whereArgs: [id]);
  }

  Future<List<DesignEdgeModel>> getEdges(int moduleRef) async {
    final rows = await db.query('design_edge',
        where: 'module_ref=?', whereArgs: [moduleRef], orderBy: 'id');
    return rows.map(DesignEdgeModel.fromMap).toList();
  }

  /// UNIQUE(from_ref, to_ref) — connecting the same pair twice is a no-op.
  Future<void> addEdge({
    required int moduleRef,
    required int fromRef,
    required int toRef,
    String? label,
  }) async {
    await db.insert(
      'design_edge',
      {'module_ref': moduleRef, 'from_ref': fromRef, 'to_ref': toRef, 'label': label},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteEdge(int id) async {
    await db.delete('design_edge', where: 'id=?', whereArgs: [id]);
  }
}
