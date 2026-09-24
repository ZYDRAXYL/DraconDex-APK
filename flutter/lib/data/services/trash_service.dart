import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';
import 'vault_snapshot_service.dart';

class TrashEntry {
  final int id;
  final int? parentRef;
  final String? parentName;
  final String name;
  final String kind;
  final int moduleCount;
  final String deletedAt;
  const TrashEntry(this.id, this.parentRef, this.parentName, this.name, this.kind, this.moduleCount, this.deletedAt);
}

/// Trash (V5.md §11.4) — the port of EXE db/trash.js. Deleting a module:
///   1. serializes it and everything under it (the .mddx snapshot, scoped)
///   2. saves every relation touching anything inside it, either way — a
///      scoped snapshot carries none, and the ones pointing IN from outside
///      are what a restore must not lose
///   3. deletes the rows for real.
/// Restore imports the snapshot under its old parent (top level if that is
/// gone) and re-adds the relations with the inside keys remapped. The
/// module's version history does not come back.
class TrashService {
  static Future<int?> trashModule(Database db, int nexusId, int moduleId) async {
    final m = await db.rawQuery('SELECT id, parent_id, name, kind FROM module WHERE id=? AND nexus_ref=?', [moduleId, nexusId]);
    if (m.isEmpty) return null;
    final ids = await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, moduleId);
    final payload = await VaultSnapshotService.serializeVault(db, nexusId, moduleIds: ids);
    if (payload == null) return null;
    final keys = [...await EntityKinds.keysOwnedBy(db, ids)];
    final inside = keys.toSet();
    final rows = [
      for (final r in await db.rawQuery('SELECT * FROM entity_relation WHERE nexus_ref=?', [nexusId]))
        if (inside.contains(r['from_key']) || inside.contains(r['to_key'])) r,
    ];
    return db.transaction((tx) async {
      final id = await tx.insert('trash', {
        'nexus_ref': nexusId,
        'parent_ref': m.first['parent_id'],
        'name': m.first['name'],
        'kind': m.first['kind'],
        'module_count': ids.length,
        'payload': jsonEncode(payload),
        'relations': jsonEncode({'keys': keys, 'rows': rows}),
      });
      // The saved rows go with the subtree; left behind they would dangle.
      for (final r in rows) {
        await tx.delete('entity_relation', where: 'id=?', whereArgs: [r['id']]);
      }
      await tx.delete('module', where: 'id=?', whereArgs: [moduleId]);
      return id;
    });
  }

  static Future<List<TrashEntry>> list(DatabaseExecutor db, int nexusId) async => [
        for (final r in await db.rawQuery('''
          SELECT t.id, t.parent_ref, t.name, t.kind, t.module_count, t.deleted_at, p.name AS parent_name
          FROM trash t LEFT JOIN module p ON p.id=t.parent_ref WHERE t.nexus_ref=? ORDER BY t.id DESC''', [nexusId]))
          TrashEntry(r['id'] as int, r['parent_ref'] as int?, r['parent_name'] as String?, r['name'] as String,
              r['kind'] as String, r['module_count'] as int? ?? 1, r['deleted_at'] as String? ?? ''),
      ];

  /// The restored root module's new id, or null when nothing came back.
  static Future<int?> restore(Database db, int nexusId, int trashId) async {
    final t = await db.rawQuery('SELECT * FROM trash WHERE id=? AND nexus_ref=?', [trashId, nexusId]);
    if (t.isEmpty) return null;
    final row = t.first;
    // The old parent may be gone, or no longer a folder — top level then.
    int? parent;
    if (row['parent_ref'] != null) {
      final p = await db.rawQuery("SELECT id FROM module WHERE id=? AND kind='collector'", [row['parent_ref']]);
      parent = p.isEmpty ? null : p.first['id'] as int;
    }
    final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    final r = await VaultSnapshotService.importModuleSnapshot(db, nexusId, parent, payload);
    if (!r.ok) return null;
    final saved = jsonDecode(row['relations'] as String? ?? '{}');
    final keys = saved is Map ? [for (final k in saved['keys'] as List? ?? const []) '$k'] : <String>[];
    final rows = saved is Map ? [for (final x in saved['rows'] as List? ?? const []) x as Map<String, dynamic>] : <Map<String, dynamic>>[];
    final inside = keys.toSet();
    String? remap(Object? k) {
      if (k is! String) return null;
      if (!inside.contains(k)) return k; // an endpoint outside kept its id
      return EntityKinds.remap(k, r.keyMaps);
    }

    await db.transaction((tx) async {
      Future<int?> mod(Object? id) async {
        if (id is! int) return null;
        final to = r.keyMaps['module']?[id];
        if (to != null) return to;
        return (await tx.rawQuery('SELECT 1 FROM module WHERE id=?', [id])).isEmpty ? null : id;
      }

      for (final x in rows) {
        final fk = remap(x['from_key']), tk = remap(x['to_key']);
        final rt0 = x['rel_type'] as String?;
        final rt = rt0 != null && RegExp(r'^ctpl_\d+$').hasMatch(rt0) ? remap(rt0) : rt0;
        if (fk == null || tk == null || (rt0 != null && rt == null)) continue;
        await tx.insert(
          'entity_relation',
          {
            'nexus_ref': nexusId,
            'from_key': fk,
            'to_key': tk,
            'label': x['label'],
            'color': x['color'],
            'rel_type': rt,
            'directed': x['directed'] ?? 1,
            'module_ref': await mod(x['module_ref']),
            'valid_from': x['valid_from'],
            'valid_to': x['valid_to'],
            'create_at': ?x['create_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await tx.delete('trash', where: 'id=?', whereArgs: [trashId]);
    });
    final mods = [for (final m in payload['modules'] as List? ?? const []) m as Map<String, dynamic>];
    final inPayload = {for (final m in mods) m['id']};
    final root = mods.where((m) => m['parentId'] == null || !inPayload.contains(m['parentId'])).firstOrNull;
    return root == null ? null : r.keyMaps['module']?[root['id']];
  }

  static Future<void> delete(DatabaseExecutor db, int nexusId, int trashId) =>
      db.delete('trash', where: 'id=? AND nexus_ref=?', whereArgs: [trashId, nexusId]);

  static Future<void> empty(DatabaseExecutor db, int nexusId) => db.delete('trash', where: 'nexus_ref=?', whereArgs: [nexusId]);
}
