import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';

import '../../core/database/module_parents.dart';
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

  /// Every pinned module of [nexusRef], at any depth.
  Future<List<ModuleModel>> getPinnedModules(int nexusRef) async {
    final rows = await db.rawQuery(
      '$_selectModule WHERE m.nexus_ref=? AND m.pinned=1 '
      'ORDER BY m.display_order, m.name COLLATE NOCASE',
      [nexusRef],
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
    // Only a Collector holds modules (v5, APP docs/V5.md §8.8).
    await assertCollectorParent(db, parentId);
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM module WHERE nexus_ref=? AND parent_id IS ?',
      [nexusRef, parentId],
    );
    final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
    final id = await db.insert('module', {
      'nexus_ref': nexusRef,
      'parent_id': parentId,
      'name': name,
      'kind': kind.id,
      'icon': icon,
      'icon_color': iconColorId,
      'color': colorId,
      'display_order': nextOrder,
    });
    // [[links]] typed before this module existed now find it.
    await WikiService.resolveDangling(db, name, nexusRef);
    return id;
  }

  Future<void> renameModule(int id, String name) async {
    final old = await db.rawQuery('SELECT name, nexus_ref FROM module WHERE id=?', [id]);
    await db.rawUpdate(
      "UPDATE module SET name=?,update_at=datetime('now') WHERE id=?",
      [name, id],
    );
    // Every [[Old name]] that linked here follows the rename.
    if (old.isNotEmpty) {
      await WikiService.renamed(db, 'module_$id', old.first['name'] as String?, name, old.first['nexus_ref'] as int?);
    }
  }

  Future<void> updateModuleDescription(int id, String? description) async {
    await db.rawUpdate(
      "UPDATE module SET description=?,update_at=datetime('now') WHERE id=?",
      [description, id],
    );
    await WikiService.reindexSource(db, 'module', id);
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

  /// Reparents [id] under [newParentId] (null = move to nexus root). With
  /// [orderedSiblingIds] — the new parent's children in their new order,
  /// [id] included — it also rewrites their display_order 0..n, one call for
  /// a move and a reorder alike, the same contract as EXE db/module.js
  /// moveModule(nx, id, parentId, orderedSiblingIds). Without it the module
  /// lands after the siblings already there.
  ///
  /// Refused (a [ModuleParentError]) when [newParentId] is not a Collector or is [id]
  /// itself or one of its descendants — a folder cannot go inside itself.
  Future<void> moveModule(int id, {required int nexusRef, int? newParentId, List<int>? orderedSiblingIds}) async {
    await assertCollectorParent(db, newParentId);
    if (newParentId != null && await isDescendant(id, newParentId)) {
      throw const ModuleParentError('a module cannot move into its own subtree');
    }
    await db.transaction((txn) async {
      if (orderedSiblingIds == null) {
        final orderRows = await txn.rawQuery(
          'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM module WHERE nexus_ref=? AND parent_id IS ? AND id<>?',
          [nexusRef, newParentId, id],
        );
        final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
        await txn.rawUpdate(
          "UPDATE module SET parent_id=?,display_order=?,update_at=datetime('now') WHERE id=?",
          [newParentId, nextOrder, id],
        );
        return;
      }
      await txn.rawUpdate(
        "UPDATE module SET parent_id=?,update_at=datetime('now') WHERE id=?",
        [newParentId, id],
      );
      for (var i = 0; i < orderedSiblingIds.length; i++) {
        await txn.rawUpdate(
          'UPDATE module SET display_order=? WHERE id=? AND nexus_ref=? AND parent_id IS ?',
          [i, orderedSiblingIds[i], nexusRef, newParentId],
        );
      }
    });
  }

  /// Moves every module of [ids] under [newParentId], in the order given,
  /// after what is already there. A module that cannot go there (the target
  /// is inside it) is skipped and returned, so a multi-select move of a
  /// folder together with its own child does what it can and says what not.
  Future<List<int>> moveModules(List<int> ids, {required int nexusRef, int? newParentId}) async {
    await assertCollectorParent(db, newParentId);
    final skipped = <int>[];
    for (final id in ids) {
      if (newParentId != null && await isDescendant(id, newParentId)) {
        skipped.add(id);
        continue;
      }
      await moveModule(id, nexusRef: nexusRef, newParentId: newParentId);
    }
    return skipped;
  }

  /// Moves [id] one place up ([delta] -1) or down (+1) among its siblings,
  /// in the order the list shows them (pinned first, then display_order).
  Future<void> shiftModule(int id, int delta) async {
    final m = await getModule(id);
    if (m == null) return;
    final siblings = [for (final s in await getModules(m.nexusRef, m.parentId)) s.id];
    final at = siblings.indexOf(id);
    final to = at + delta;
    if (at < 0 || to < 0 || to >= siblings.length) return;
    siblings
      ..removeAt(at)
      ..insert(to, id);
    await moveModule(id, nexusRef: m.nexusRef, newParentId: m.parentId, orderedSiblingIds: siblings);
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
