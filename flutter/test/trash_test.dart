import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/mddx.dart';
import 'package:dracondex/data/services/problems_service.dart';
import 'package:dracondex/data/services/trash_service.dart';
import 'package:dracondex/data/services/wiki_service.dart';

/// Trash (V5.md §11.4, EXE db/trash.js) and Problems (§11.10).
void main() {
  sqfliteFfiInit();
  late Database db;
  late int nx;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    nx = await db.insert('nexus', {'name': 'W'});
  });
  tearDown(() => db.close());

  test('trash then restore brings the subtree and its relations back', () async {
    final mods = ModuleDao(db);
    final folder = await mods.createModule(nexusRef: nx, name: 'People', kind: ModuleKind.collector);
    final cast = await mods.createModule(nexusRef: nx, parentId: folder, name: 'Cast', kind: ModuleKind.classifier);
    final places = await mods.createModule(nexusRef: nx, name: 'Places', kind: ModuleKind.classifier);
    final cls = ClassifierDao(db);
    final ana = await cls.createItem(moduleRef: cast, name: 'Ana');
    final town = await cls.createItem(moduleRef: places, name: 'Town');
    // One relation pointing IN from outside, one relation-field row going out.
    await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'cobj_$town', 'to_key': 'cobj_$ana', 'label': 'home of'});
    final f = await cls.createField(moduleRef: cast, description: 'Lives in', attributeType: 'relation');
    await cls.addFieldRelation(ana, f, 'cobj_$town');

    final tid = await TrashService.trashModule(db, nx, folder);
    expect(tid, isNotNull);
    expect(await db.rawQuery('SELECT 1 FROM module WHERE id IN (?,?)', [folder, cast]), isEmpty);
    expect(await db.rawQuery('SELECT 1 FROM entity_relation'), isEmpty, reason: 'saved with the subtree, not left dangling');
    final list = await TrashService.list(db, nx);
    expect((list.single.name, list.single.moduleCount), ('People', 2));

    final root = await TrashService.restore(db, nx, tid!);
    expect(root, isNotNull);
    expect((await db.rawQuery('SELECT name FROM module WHERE id=?', [root])).single['name'], 'People');
    final newCast = (await db.rawQuery("SELECT id FROM module WHERE name='Cast'")).single['id'] as int;
    final newAna = (await db.rawQuery('SELECT id FROM classifier_object WHERE module_ref=?', [newCast])).single['id'] as int;
    final newField = (await db.rawQuery('SELECT id FROM classifier_template WHERE module_ref=?', [newCast])).single['id'] as int;
    final rels = await db.rawQuery('SELECT from_key, to_key, rel_type FROM entity_relation ORDER BY id');
    expect(rels.map((r) => (r['from_key'], r['to_key'], r['rel_type'])).toSet(), {
      ('cobj_$town', 'cobj_$newAna', null),
      ('cobj_$newAna', 'cobj_$town', 'ctpl_$newField'),
    });
    expect(await TrashService.list(db, nx), isEmpty);
  });

  test('restore lands at top level when the old parent is gone', () async {
    final mods = ModuleDao(db);
    final folder = await mods.createModule(nexusRef: nx, name: 'F', kind: ModuleKind.collector);
    final d = await mods.createModule(nexusRef: nx, parentId: folder, name: 'Doc', kind: ModuleKind.drafter);
    final tid = (await TrashService.trashModule(db, nx, d))!;
    await mods.deleteModule(folder);
    final root = await TrashService.restore(db, nx, tid);
    expect((await db.rawQuery('SELECT parent_id FROM module WHERE id=?', [root])).single['parent_id'], isNull);
  });

  test('problems: an unresolved link, an empty module, a relation with a missing end', () async {
    final mods = ModuleDao(db);
    final d = await mods.createModule(nexusRef: nx, name: 'Doc', kind: ModuleKind.drafter);
    await mods.updateModuleDescription(d, 'See [[Nowhere]]');
    await WikiService.reindexSource(db, 'module', d);
    await mods.createModule(nexusRef: nx, name: 'Empty cast', kind: ModuleKind.classifier);
    await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'module_$d', 'to_key': 'cobj_999'});
    final ps = await ProblemsService.list(db, nx);
    expect(ps.map((p) => (p.type, p.name)).toSet(), {('link', 'Doc'), ('empty', 'Empty cast'), ('relation', 'Doc')});
    expect(ps.firstWhere((p) => p.type == 'link').detail, '[[Nowhere]]');
  });

  test('.mddx: a module exported and imported comes back as a copy', () async {
    final mods = ModuleDao(db);
    final cast = await mods.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    await ClassifierDao(db).createItem(moduleRef: cast, name: 'Ana');
    final bytes = await Mddx.export(db, nx, cast);
    final other = await db.insert('nexus', {'name': 'Other'});
    final id = await Mddx.import(db, other, null, bytes!);
    expect((await db.rawQuery('SELECT name, nexus_ref FROM module WHERE id=?', [id])).single, {'name': 'Cast', 'nexus_ref': other});
    expect((await db.rawQuery('SELECT name FROM classifier_object WHERE module_ref=?', [id])).single['name'], 'Ana');
    expect(await Mddx.import(db, other, null, Uint8List.fromList('not json'.codeUnits)), isNull);
  });
}
