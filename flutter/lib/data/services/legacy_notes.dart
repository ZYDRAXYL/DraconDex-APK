import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';

/// Legacy Scribe notes become modules (v5 Part 8, APP docs/APK-V3.md §10.5,
/// §13 item 9) — the port of EXE `db/migrate_v3.js`'s scribe branch and
/// `rewriteNoteKeys`, so a note that arrives from an older desktop build (or
/// was written on this device before V3) turns into the same modules here as
/// it would there:
///
///  * one top-level Collector "Scribe", the `note_folder` tree as nested
///    Collectors under it, each note an Inspector with the note's text as
///    its description and `module_ui.legacyNote` = the note's id;
///  * every stored `note_<id>` key (every KEY_COLUMNS column, and wiki_link)
///    now names the module, so no link or relation points at nothing once
///    the snapshot stops carrying converted notes;
///  * `migrated_v3=1` on every note of the Nexus.
///
/// Modules are find-or-create on (parent, kind, name), the same as EXE's
/// `mkModule`, so a second conversion never duplicates what the first made.
class LegacyNotes {
  /// Converts every Nexus's unconverted notes; returns how many notes moved.
  /// One COUNT when there is nothing to do — every open after the first.
  static Future<int> migrateAll(Database db) async {
    final rows = await db.rawQuery('SELECT DISTINCT nexus_ref FROM note WHERE migrated_v3=0 AND nexus_ref IS NOT NULL');
    var n = 0;
    for (final r in rows) {
      n += await migrate(db, r['nexus_ref'] as int);
    }
    return n;
  }

  static Future<int> migrate(Database db, int nexusId) async {
    var count = 0;
    await db.transaction((d) async {
      Future<int> mkModule(int? parentId, String name, String kind) async {
        final existing = await d.rawQuery(
            'SELECT id FROM module WHERE nexus_ref=? AND parent_id IS ? AND kind=? AND name=?',
            [nexusId, parentId, kind, name]);
        if (existing.isNotEmpty) return existing.first['id'] as int;
        final order = await d.rawQuery(
            'SELECT COALESCE(MAX(display_order), -1) + 1 AS o FROM module WHERE nexus_ref=? AND parent_id IS ?',
            [nexusId, parentId]);
        return d.rawInsert(
            'INSERT INTO module (nexus_ref, parent_id, name, kind, display_order) VALUES (?,?,?,?,?)',
            [nexusId, parentId, name, kind, order.first['o']]);
      }

      final notes = await d.rawQuery('SELECT * FROM note WHERE nexus_ref=? AND migrated_v3=0 ORDER BY id', [nexusId]);
      if (notes.isEmpty) return;
      final major = await mkModule(null, 'Scribe', 'collector');

      final folders = await d.rawQuery('SELECT * FROM note_folder WHERE nexus_ref=? ORDER BY id', [nexusId]);
      final byParent = <int?, List<Map<String, Object?>>>{};
      for (final f in folders) {
        (byParent[f['parent_ref'] as int?] ??= []).add(f);
      }
      final folderMod = <int, int>{};
      Future<void> walk(int? parentFolder, int parentModule) async {
        for (final f in byParent[parentFolder] ?? const <Map<String, Object?>>[]) {
          final cid = await mkModule(parentModule, '${f['name']}', 'collector');
          folderMod[f['id'] as int] = cid;
          await walk(f['id'] as int, cid);
        }
      }

      await walk(null, major);

      final moved = <(int, int)>[];
      for (final n in notes) {
        final folder = n['folder_ref'] as int?;
        final parent = folder == null ? major : (folderMod[folder] ?? major);
        final mid = await mkModule(parent, '${n['title'] ?? ''}', 'inspector');
        final content = n['content'] as String?;
        if (content != null && content.isNotEmpty) {
          await d.rawUpdate("UPDATE module SET description=?, update_at=datetime('now') WHERE id=?", [content, mid]);
        }
        await d.rawInsert(
            "INSERT OR REPLACE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?, 'legacyNote', ?)",
            [mid, '${n['id']}']);
        moved.add((n['id'] as int, mid));
      }
      await rewriteNoteKeys(d, moved);
      await d.rawUpdate('UPDATE note SET migrated_v3=1 WHERE nexus_ref=? AND migrated_v3=0', [nexusId]);
      count = notes.length;
    });
    return count;
  }

  /// Every stored `note_<id>` becomes `module_<mid>`. A JSON column holds
  /// the key quoted; entity_relation is UNIQUE, so a rewrite that would
  /// duplicate a relation the module already has is dropped instead.
  static Future<void> rewriteNoteKeys(DatabaseExecutor d, List<(int, int)> moved) async {
    for (final (noteId, mid) in moved) {
      final from = 'note_$noteId';
      final to = 'module_$mid';
      for (final k in keyColumns) {
        for (final col in k.cols) {
          try {
            if (k.json) {
              await d.rawUpdate('UPDATE ${k.table} SET $col=REPLACE($col, ?, ?) WHERE $col LIKE ?',
                  ['"$from"', '"$to"', '%"$from"%']);
            } else {
              await d.rawUpdate('UPDATE OR IGNORE ${k.table} SET $col=? WHERE $col=?', [to, from]);
            }
          } catch (_) {
            // A table this vault does not have.
          }
        }
      }
      await d.rawDelete('DELETE FROM entity_relation WHERE from_key=? OR to_key=?', [from, from]);
      await d.rawUpdate('UPDATE OR IGNORE wiki_link SET target_key=? WHERE target_key=?', [to, from]);
      await d.rawDelete('DELETE FROM wiki_link WHERE src_key=? OR target_key=?', [from, from]);
    }
  }

  /// The module a converted note became, or null.
  static Future<int?> moduleOfNote(DatabaseExecutor db, int noteId) async {
    final r = await db.rawQuery("SELECT module_ref FROM module_ui WHERE ui_key='legacyNote' AND ui_value=?", ['$noteId']);
    return r.isEmpty ? null : r.first['module_ref'] as int?;
  }
}
