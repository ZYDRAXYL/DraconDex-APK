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

  Future<void> updateNode(int id, {String? text, String? shape}) async {
    await db.rawUpdate(
      "UPDATE design_node SET node_text=?,shape=?,update_at=datetime('now') WHERE id=?",
      [text, shape ?? 'box', id],
    );
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
