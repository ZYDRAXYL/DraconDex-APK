import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/module_parents.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/legacy_notes.dart';

/// Legacy notes become modules the way EXE's migrate_v3.js makes them, and
/// every key that named a note names the module after (APP docs/APK-V3.md
/// §10.5, §13 item 9). Plus the v5 rule that only a Collector holds modules.
void main() {
  sqfliteFfiInit();

  Future<Database> openVault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return db;
  }

  test('notes and their folders become Inspectors under a Scribe collector', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'World'});
    final lore = await db.insert('note_folder', {'nexus_ref': nx, 'name': 'Lore'});
    final deep = await db.insert('note_folder', {'nexus_ref': nx, 'parent_ref': lore, 'name': 'Deep'});
    final a = await db.insert('note', {'nexus_ref': nx, 'folder_ref': deep, 'title': 'Sundering', 'content': 'Long ago.'});
    final b = await db.insert('note', {'nexus_ref': nx, 'title': 'Loose', 'content': ''});
    final other = await db.insert('module', {'nexus_ref': nx, 'name': 'Book', 'kind': 'author'});
    await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'module_$other', 'to_key': 'note_$a'});
    await db.insert('wiki_link', {'nexus_ref': nx, 'src_key': 'module_$other', 'target_key': 'note_$a', 'target_text': 'Sundering'});
    await db.insert('page_block', {'module_ref': other, 'block_type': 'component', 'component': 'x', 'source_key': 'note_$b'});

    expect(await LegacyNotes.migrateAll(db), 2);

    final mods = {
      for (final r in await db.rawQuery('SELECT id, parent_id, name, kind, description FROM module')) r['name']: r,
    };
    expect(mods['Scribe']!['kind'], 'collector');
    expect(mods['Lore']!['parent_id'], mods['Scribe']!['id']);
    expect(mods['Deep']!['parent_id'], mods['Lore']!['id']);
    expect(mods['Sundering']!['kind'], 'inspector');
    expect(mods['Sundering']!['parent_id'], mods['Deep']!['id']);
    expect(mods['Sundering']!['description'], 'Long ago.');
    expect(mods['Loose']!['parent_id'], mods['Scribe']!['id']);

    final sundering = mods['Sundering']!['id'] as int;
    expect(await LegacyNotes.moduleOfNote(db, a), sundering);
    final rel = await db.rawQuery('SELECT to_key FROM entity_relation');
    expect(rel.single['to_key'], 'module_$sundering');
    final link = await db.rawQuery('SELECT target_key FROM wiki_link');
    expect(link.single['target_key'], 'module_$sundering');
    final block = await db.rawQuery('SELECT source_key FROM page_block');
    expect(block.single['source_key'], 'module_${mods['Loose']!['id']}');
    expect(await db.rawQuery('SELECT id FROM note WHERE migrated_v3=0'), isEmpty);

    // A second pass has nothing to do and makes nothing twice.
    expect(await LegacyNotes.migrateAll(db), 0);
    expect((await db.rawQuery("SELECT id FROM module WHERE name='Scribe'")).length, 1);
  });

  test('only a Collector holds modules, and an old tree is wrapped, not lost', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'World'});
    final dao = ModuleDao(db);
    final folder = await dao.createModule(nexusRef: nx, name: 'Folder', kind: ModuleKind.collector);
    final cast = await dao.createModule(nexusRef: nx, parentId: folder, name: 'Cast', kind: ModuleKind.classifier);
    expect(() => dao.createModule(nexusRef: nx, parentId: cast, name: 'X', kind: ModuleKind.author),
        throwsA(isA<ModuleParentError>()));
    expect(() => dao.moveModule(folder, nexusRef: nx, newParentId: cast), throwsA(isA<ModuleParentError>()));

    // What an older build could write: a Manager holding modules.
    final project = await db.insert('module', {'nexus_ref': nx, 'name': 'Project', 'kind': 'manager', 'display_order': 5});
    final inside = await db.insert('module', {'nexus_ref': nx, 'parent_id': project, 'name': 'Notes', 'kind': 'drafter'});
    final r = await db.transaction((t) => normalizeModuleParents(t));
    expect(r.collectors, 1);
    expect(r.moved, 1);
    final wrap = await db.rawQuery("SELECT id, parent_id FROM module WHERE kind='collector' AND name='Project'");
    final moved = await db.rawQuery('SELECT parent_id FROM module WHERE id=?', [inside]);
    expect(moved.single['parent_id'], wrap.single['id']);
    final filter = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='filterDef'", [project]);
    expect(filter.single['ui_value'], contains('"childOf"'));
  });
}
