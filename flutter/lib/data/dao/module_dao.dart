import 'package:sqflite/sqflite.dart';
import '../models/module_model.dart';

/// Data access for the v3 module system (Hub/Nexus nest): a Nexus is a
/// vault, `module` is its self-nesting tree browsed by drilling down.
class ModuleDao {
  final Database db;
  ModuleDao(this.db);

  // ---- Nexus CRUD ---------------------------------------------------------

  Future<List<NexusModel>> getNexuses() async {
    final rows = await db.rawQuery('''
      SELECT n.*, uc.color_code FROM nexus n
      LEFT JOIN use_color uc ON n.color=uc.id
      ORDER BY n.name
    ''');
    return rows.map(NexusModel.fromMap).toList();
  }

  Future<NexusModel?> getNexus(int id) async {
    final rows = await db.rawQuery('''
      SELECT n.*, uc.color_code FROM nexus n
      LEFT JOIN use_color uc ON n.color=uc.id WHERE n.id=?
    ''', [id]);
    if (rows.isEmpty) return null;
    return NexusModel.fromMap(rows.first);
  }

  Future<int> createNexus({required String name, String? memo, int? colorId}) async {
    return db.insert('nexus', {'name': name, 'memo': memo, 'color': colorId});
  }

  Future<void> updateNexus(int id, {required String name, String? memo, int? colorId}) async {
    await db.rawUpdate(
      "UPDATE nexus SET name=?,memo=?,color=?,update_at=datetime('now') WHERE id=?",
      [name, memo, colorId, id],
    );
  }

  Future<void> deleteNexus(int id) async {
    await db.delete('nexus', where: 'id=?', whereArgs: [id]);
  }

  // ---- Module tree ---------------------------------------------------------

  static const _selectModule = '''
    SELECT m.*, uc.color_code, uic.color_code AS icon_color_code,
      (SELECT COUNT(*) FROM module c WHERE c.parent_id = m.id) AS child_count
    FROM module m
    LEFT JOIN use_color uc ON m.color=uc.id
    LEFT JOIN use_color uic ON m.icon_color=uic.id
  ''';

  /// Direct children of [parentId] within [nexusRef] (null = top-level).
  Future<List<ModuleModel>> getModules(int nexusRef, int? parentId) async {
    final rows = await db.rawQuery(
      '$_selectModule WHERE m.nexus_ref=? AND m.parent_id IS ? '
      'ORDER BY m.pinned DESC, m.display_order, m.name COLLATE NOCASE',
      [nexusRef, parentId],
    );
    return rows.map(ModuleModel.fromMap).toList();
  }

  Future<ModuleModel?> getModule(int id) async {
    final rows = await db.rawQuery('$_selectModule WHERE m.id=?', [id]);
    if (rows.isEmpty) return null;
    return ModuleModel.fromMap(rows.first);
  }

  /// Ancestor chain from the Nexus root down to (excluding) [id], for
  /// breadcrumbs. Walks parent_id one hop at a time — trees here are never
  /// deep enough for this to matter perf-wise.
  Future<List<ModuleModel>> getAncestors(int id) async {
    final chain = <ModuleModel>[];
    int? current = id;
    while (current != null) {
      final m = await getModule(current);
      if (m == null) break;
      if (m.id != id) chain.add(m);
      current = m.parentId;
    }
    return chain.reversed.toList();
  }

  Future<int> createModule({
    required int nexusRef,
    int? parentId,
    required String name,
    required ModuleKind kind,
    String? icon,
    int? iconColorId,
    int? colorId,
  }) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM module WHERE nexus_ref=? AND parent_id IS ?',
      [nexusRef, parentId],
    );
    final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
    return db.insert('module', {
      'nexus_ref': nexusRef,
      'parent_id': parentId,
      'name': name,
      'kind': kind.id,
      'icon': icon,
      'icon_color': iconColorId,
      'color': colorId,
      'display_order': nextOrder,
    });
  }

  Future<void> renameModule(int id, String name) async {
    await db.rawUpdate(
      "UPDATE module SET name=?,update_at=datetime('now') WHERE id=?",
      [name, id],
    );
  }

  Future<void> updateModuleDescription(int id, String? description) async {
    await db.rawUpdate(
      "UPDATE module SET description=?,update_at=datetime('now') WHERE id=?",
      [description, id],
    );
  }

  Future<void> updateModuleAppearance(int id, {String? icon, int? iconColorId, int? colorId}) async {
    await db.rawUpdate(
      "UPDATE module SET icon=?,icon_color=?,color=?,update_at=datetime('now') WHERE id=?",
      [icon, iconColorId, colorId, id],
    );
  }

  Future<void> setPinned(int id, bool pinned) async {
    await db.rawUpdate(
      "UPDATE module SET pinned=?,update_at=datetime('now') WHERE id=?",
      [pinned ? 1 : 0, id],
    );
  }

  /// Reparents [id] under [newParentId] (null = move to nexus root), placed
  /// after existing siblings there. Caller must ensure newParentId isn't [id]
  /// or one of its own descendants — see [isDescendant].
  Future<void> moveModule(int id, {required int nexusRef, int? newParentId}) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM module WHERE nexus_ref=? AND parent_id IS ?',
      [nexusRef, newParentId],
    );
    final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
    await db.rawUpdate(
      "UPDATE module SET parent_id=?,display_order=?,update_at=datetime('now') WHERE id=?",
      [newParentId, nextOrder, id],
    );
  }

  /// Whether [candidateAncestorId] is [id] itself or one of its descendants
  /// — used to block a drag/move that would nest a module inside itself.
  Future<bool> isDescendant(int id, int candidateAncestorId) async {
    if (id == candidateAncestorId) return true;
    final children = await db.rawQuery('SELECT id FROM module WHERE parent_id=?', [id]);
    for (final row in children) {
      if (await isDescendant(row['id'] as int, candidateAncestorId)) return true;
    }
    return false;
  }

  Future<void> deleteModule(int id) async {
    await db.delete('module', where: 'id=?', whereArgs: [id]);
  }
}
