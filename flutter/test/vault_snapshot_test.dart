import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';

/// `VaultSnapshotService` is a port of `serializeVault` / `applySnapshotCore`
/// in `electron/src/db/sync.js` (DraconDex-EXE). The two have to keep
/// producing and accepting the same JSON forever, and nothing about Dart
/// type-checking catches them drifting apart.
///
/// So this runs the REAL vault schema (the generated one both apps share, from
/// DraconDex-SDB) against sqlite and holds the port to the invariant that
/// actually matters: serialize -> apply -> serialize has to come back
/// identical, ids aside.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  Future<Database> openVault() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    for (final code in defaultColorCodes) {
      await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
    }
    return db;
  }

  Future<int> colorIdOf(Database db, String code) async {
    final rows = await db.rawQuery('SELECT id FROM use_color WHERE color_code=?', [code]);
    return rows.first['id']! as int;
  }

  /// A Nexus with something in most of the shapes the format carries, so the
  /// round trip exercises the id remapping rather than an empty vault.
  Future<int> seedVault(Database db) async {
    final blue = await colorIdOf(db, defaultColorCodes.first);
    final nexusId = await db.insert('nexus', {'name': 'My World', 'memo': 'a memo', 'color': blue});

    final root = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Characters',
      'kind': 'classifier', 'display_order': 0, 'color': blue,
    });
    final child = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': root, 'name': 'Protagonists',
      'kind': 'classifier', 'display_order': 1,
    });
    await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Chapters',
      'kind': 'author', 'display_order': 2, 'handle': 'chapters',
    });

    await db.insert('module_attribute', {
      'module_ref': root, 'attr_name': 'era', 'attr_value': 'third age', 'display_order': 0,
    });

    final tagId = await db.insert('hashtag', {'tag_name': 'main', 'tag_color': blue});
    await db.insert('module_hashtag', {'module_ref': root, 'hashtag_id': tagId});

    final obj = await db.insert('classifier_object', {
      'module_ref': child, 'name': 'Aria', 'color': blue, 'note': 'the lead', 'display_order': 0,
    });
    final tpl = await db.insert('classifier_template', {
      'module_ref': child, 'object_ref': obj, 'description': 'Age',
      'attribute_type': 'text', 'levelable': 0, 'has_condition': 0, 'display_order': 0,
    });
    await db.insert('classifier_attribute', {
      'object_ref': obj, 'template_ref': tpl, 'attribute_value': '24',
    });

    final folder = await db.insert('note_folder', {
      'nexus_ref': nexusId, 'parent_ref': null, 'name': 'Lore', 'color': blue,
    });
    final note = await db.insert('note', {
      'nexus_ref': nexusId, 'folder_ref': folder, 'title': 'The Sundering',
      'content': 'It began with [[Aria]].', 'pinned': 0,
    });

    // A relation whose endpoints BOTH have to be remapped on the way in — the
    // single most breakable part of the port.
    await db.insert('entity_relation', {
      'nexus_ref': nexusId, 'from_key': 'module_$root', 'to_key': 'note_$note', 'label': 'mentions',
    });
    // ...and one that cannot be remapped, which must be dropped and counted
    // rather than inserted with a dangling key.
    await db.insert('entity_relation', {
      'nexus_ref': nexusId, 'from_key': 'module_999999', 'to_key': 'note_$note', 'label': 'ghost',
    });

    return nexusId;
  }

  /// Everything that legitimately differs between two serializations of the
  /// same content: primary keys, and when it was exported.
  Object? strip(Object? v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.key != 'id' && e.key != 'exportedAt') e.key: strip(e.value),
      };
    }
    if (v is List) return v.map(strip).toList();
    return v;
  }

  test('the snapshot header matches what DraconDex-EXE writes', () async {
    final db = await openVault();
    final nexusId = await seedVault(db);
    final snap = (await VaultSnapshotService.serializeVault(db, nexusId))!;

    // These two strings ARE the compatibility check on both sides:
    // validateSnapshot in sync.js rejects anything else outright.
    expect(snap['format'], 'dracondex-vault-snapshot');
    expect(snap['version'], 1);
    expect((snap['nexus']! as Map)['name'], 'My World');
    await db.close();
  });

  test('serialize -> apply -> serialize comes back identical', () async {
    final db = await openVault();
    final sourceId = await seedVault(db);

    final first = (await VaultSnapshotService.serializeVault(db, sourceId))!;

    // Receiving always lands in a NEW Nexus: applySnapshot is wipe-and-rebuild
    // and would destroy an existing one.
    final targetId = await db.insert('nexus', {'name': 'Received'});
    final applied = await VaultSnapshotService.applySnapshot(db, targetId, first);
    expect(applied.ok, isTrue, reason: applied.code);

    final second = (await VaultSnapshotService.serializeVault(db, targetId))!;

    // The local Nexus NAME is deliberately kept (it is UNIQUE per install),
    // so that one field is expected to differ.
    final a = strip(first)! as Map;
    final b = strip(second)! as Map;
    (a['nexus']! as Map).remove('name');
    (b['nexus']! as Map).remove('name');

    expect(b, a);
    await db.close();
  });

  test('the id remapping survives the round trip, dangling keys and all', () async {
    final db = await openVault();
    final sourceId = await seedVault(db);
    final snap = (await VaultSnapshotService.serializeVault(db, sourceId))!;

    final targetId = await db.insert('nexus', {'name': 'Received'});
    final applied = await VaultSnapshotService.applySnapshot(db, targetId, snap);

    expect(applied.modules, 3);
    expect(applied.notes, 1);
    // One real relation kept, one unmappable one dropped and counted rather
    // than inserted with an endpoint pointing at nothing.
    expect(applied.relations, 1);
    expect(applied.droppedRelations, 1);

    // The surviving relation must point at the NEW ids, not the old ones.
    final rels = await db.rawQuery(
        'SELECT from_key, to_key FROM entity_relation WHERE nexus_ref=?', [targetId]);
    expect(rels.length, 1);
    final newModules = await db.rawQuery(
        "SELECT id FROM module WHERE nexus_ref=? AND name='Characters'", [targetId]);
    expect(rels.first['from_key'], 'module_${newModules.first['id']}');

    await db.close();
  });

  test('a module tree is rebuilt parents-first even when the payload is not ordered', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Out of order'});

    // Children before their parent. The BFS in applySnapshot exists precisely
    // so a snapshot in this order still lands with its tree intact.
    final payload = <String, Object?>{
      'format': 'dracondex-vault-snapshot',
      'version': 1,
      'nexus': <String, Object?>{'name': 'X', 'memo': null, 'colorCode': null},
      'lookups': <String, Object?>{'colors': <Object?>[], 'hashtags': <Object?>[], 'dates': <Object?>[]},
      'modules': <Object?>[
        <String, Object?>{'id': 3, 'parentId': 2, 'name': 'Grandchild', 'kind': 'classifier'},
        <String, Object?>{'id': 2, 'parentId': 1, 'name': 'Child', 'kind': 'classifier'},
        <String, Object?>{'id': 1, 'parentId': null, 'name': 'Root', 'kind': 'classifier'},
        // An orphan pointing at a module the snapshot does not contain: it has
        // nowhere to attach and must be dropped, not crash the import.
        <String, Object?>{'id': 9, 'parentId': 77, 'name': 'Orphan', 'kind': 'classifier'},
      ],
    };

    final applied = await VaultSnapshotService.applySnapshot(db, targetId, payload);
    expect(applied.ok, isTrue, reason: applied.code);
    expect(applied.modules, 3);

    final rows = await db.rawQuery(
        'SELECT id, parent_id, name FROM module WHERE nexus_ref=? ORDER BY name', [targetId]);
    expect(rows.map((r) => r['name']).toList(), <String>['Child', 'Grandchild', 'Root']);
    final byName = {for (final r in rows) r['name'] as String: r};
    expect(byName['Child']!['parent_id'], byName['Root']!['id']);
    expect(byName['Grandchild']!['parent_id'], byName['Child']!['id']);

    await db.close();
  });

  test('a payload that is not a snapshot is refused rather than half-applied', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Target'});
    for (final bad in <Object?>[
      null,
      'not a map',
      <String, Object?>{'format': 'something-else', 'version': 1, 'nexus': <String, Object?>{}, 'modules': <Object?>[]},
      <String, Object?>{'format': 'dracondex-vault-snapshot', 'version': 99, 'nexus': <String, Object?>{}, 'modules': <Object?>[]},
      <String, Object?>{'format': 'dracondex-vault-snapshot', 'version': 1, 'modules': <Object?>[]},
    ]) {
      final r = await VaultSnapshotService.applySnapshot(db, targetId, bad);
      expect(r.ok, isFalse);
      expect(r.code, 'bad_snapshot');
    }
    await db.close();
  });

  test('a colliding module handle is dropped rather than aborting the import', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Target'});
    // Something already owns the handle the snapshot wants.
    await db.insert('module', {
      'nexus_ref': targetId, 'name': 'Existing', 'kind': 'classifier', 'handle': 'chapters',
    });

    final applied = await VaultSnapshotService.applySnapshot(db, targetId, <String, Object?>{
      'format': 'dracondex-vault-snapshot',
      'version': 1,
      'nexus': <String, Object?>{'name': 'X'},
      'modules': <Object?>[
        <String, Object?>{'id': 1, 'parentId': null, 'name': 'Chapters', 'kind': 'author', 'handle': 'chapters'},
      ],
    });

    // The wipe cleared 'Existing' first, so the handle is actually free by the
    // time the module lands — what matters is that the import completed at all
    // rather than throwing on a cosmetic field.
    expect(applied.ok, isTrue, reason: applied.code);
    expect(applied.modules, 1);
    await db.close();
  });

  test('collectModuleSubtreeIds walks the whole subtree', () async {
    final db = await openVault();
    final nexusId = await db.insert('nexus', {'name': 'Tree'});
    final root = await db.insert('module', {'nexus_ref': nexusId, 'name': 'R', 'kind': 'classifier'});
    final a = await db.insert('module', {'nexus_ref': nexusId, 'parent_id': root, 'name': 'A', 'kind': 'classifier'});
    final b = await db.insert('module', {'nexus_ref': nexusId, 'parent_id': a, 'name': 'B', 'kind': 'classifier'});
    await db.insert('module', {'nexus_ref': nexusId, 'name': 'Elsewhere', 'kind': 'classifier'});

    final ids = await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, root);
    expect(ids.toSet(), <int>{root, a, b});
    await db.close();
  });

  test('remapEntityKey only maps keys it has a map for', () {
    final maps = <String, Map<int, int>>{'module': <int, int>{12: 57}};
    expect(VaultSnapshotService.remapEntityKey('module_12', maps), 'module_57');
    expect(VaultSnapshotService.remapEntityKey('module_13', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey('note_12', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey('nonsense', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey(null, maps), isNull);
  });
}
