import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// A module's parent must be a Collector (v5 Part 4, APP docs/V5.md §8.8) —
/// the port of EXE `db/module-parents.js`. SQLite cannot CHECK it (a CHECK
/// cannot hold a subquery), so it is enforced where a parent is set
/// ([assertCollectorParent], from ModuleDao) and repaired on open
/// ([normalizeModuleParents]) for a vault or a snapshot from before the rule.
class ModuleParentError implements Exception {
  final String message;
  const ModuleParentError(this.message);
  @override
  String toString() => message;
}

Future<void> assertCollectorParent(DatabaseExecutor db, int? parentId) async {
  if (parentId == null) return;
  final p = await db.rawQuery('SELECT kind FROM module WHERE id=?', [parentId]);
  if (p.isEmpty) throw const ModuleParentError('parent module not found');
  if (p.first['kind'] != 'collector') throw const ModuleParentError('parent must be a collector');
}

/// Each non-collector that has children gets a Collector of the same name
/// right after it, and its children move into that. Moved, never deleted:
/// the module count before and after is checked. Shallowest parent first,
/// so once a parent's own place is valid the collector beside it is too.
///
/// A former Manager keeps showing what it showed: its filter is pointed at
/// the new Collector (§8.9 — a Manager reads a selection, not children).
Future<({int moved, int collectors})> normalizeModuleParents(DatabaseExecutor db) async {
  Future<List<Map<String, Object?>>> offenders() => db.rawQuery('''
    SELECT DISTINCT p.id, p.nexus_ref, p.parent_id, p.name, p.kind, p.display_order
    FROM module c JOIN module p ON c.parent_id=p.id WHERE p.kind <> 'collector' ''');
  Future<int> depthOf(int id) async {
    var n = 0;
    int? cur = id;
    while (cur != null && n < 10000) {
      final r = await db.rawQuery('SELECT parent_id FROM module WHERE id=?', [cur]);
      cur = r.isEmpty ? null : r.first['parent_id'] as int?;
      n++;
    }
    return n;
  }

  Future<int> count() async => (await db.rawQuery('SELECT COUNT(*) AS n FROM module')).first['n'] as int;
  final before = await count();
  var moved = 0;
  var made = 0;
  for (var guard = 0; guard < 100000; guard++) {
    final rows = [...await offenders()];
    if (rows.isEmpty) break;
    final depths = {for (final r in rows) r['id'] as int: await depthOf(r['id'] as int)};
    rows.sort((a, b) => depths[a['id']]!.compareTo(depths[b['id']]!));
    final p = rows.first;
    final order = (p['display_order'] as int?) ?? 0;
    final found = await db.rawQuery(
        "SELECT id FROM module WHERE nexus_ref=? AND parent_id IS ? AND kind='collector' AND name=?",
        [p['nexus_ref'], p['parent_id'], p['name']]);
    int cid;
    if (found.isNotEmpty) {
      cid = found.first['id'] as int;
    } else {
      await db.rawUpdate(
          'UPDATE module SET display_order=display_order+1 WHERE nexus_ref=? AND parent_id IS ? AND display_order>?',
          [p['nexus_ref'], p['parent_id'], order]);
      cid = await db.rawInsert(
          "INSERT INTO module (nexus_ref, parent_id, name, kind, display_order) VALUES (?,?,?,'collector',?)",
          [p['nexus_ref'], p['parent_id'], p['name'], order + 1]);
      made++;
    }
    moved += await db.rawUpdate('UPDATE module SET parent_id=? WHERE parent_id=?', [cid, p['id']]);
    if (p['kind'] == 'manager') {
      final has = await db.rawQuery(
          "SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='filterDef'", [p['id']]);
      var groups = const <Object?>[];
      try {
        final def = jsonDecode(has.isEmpty ? '{}' : '${has.first['ui_value'] ?? '{}'}');
        if (def is Map && def['groups'] is List) groups = def['groups'] as List;
      } catch (_) {}
      if (groups.isEmpty) {
        final def = jsonEncode({
          'groups': [
            {
              'rules': [
                {'field': 'childOf', 'moduleId': cid},
              ],
            },
          ],
        });
        await db.execute(
            "INSERT INTO module_ui (module_ref, ui_key, ui_value) VALUES (?, 'filterDef', ?) "
            'ON CONFLICT(module_ref, ui_key) DO UPDATE SET ui_value=excluded.ui_value',
            [p['id'], def]);
      }
    }
  }
  final after = await count();
  if (after != before + made) {
    throw StateError('module parent normalize: count $before+$made != $after');
  }
  return (moved: moved, collectors: made);
}
