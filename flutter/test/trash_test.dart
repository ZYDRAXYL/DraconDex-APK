import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/assets/asset_store.dart';
import 'package:dracondex/data/services/mddx.dart';
import 'package:dracondex/data/services/problems_service.dart';
import 'package:dracondex/data/services/trash_service.dart';
import 'package:dracondex/data/services/wiki_service.dart';
import 'package:dracondex/features/page/component_registry.dart';

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
    final rank = await cls.createField(moduleRef: cast, description: 'Rank');
    await cls.updateField(rank, description: 'Rank', type: 'text', levelable: true);
    for (final lv in ['I', 'II']) {
      await cls.updateLevelField(await cls.createLevel(ana, rank), 'level_label', lv);
    }

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
    final newField =
        (await db.rawQuery("SELECT id FROM classifier_template WHERE module_ref=? AND description='Lives in'", [newCast])).single['id'] as int;
    final rels = await db.rawQuery('SELECT from_key, to_key, rel_type FROM entity_relation ORDER BY id');
    expect(rels.map((r) => (r['from_key'], r['to_key'], r['rel_type'])).toSet(), {
      ('cobj_$town', 'cobj_$newAna', null),
      ('cobj_$newAna', 'cobj_$town', 'ctpl_$newField'),
    });
    // A levelled field's rows come back on the new object and field.
    final newRank = (await cls.getFields(newCast)).firstWhere((x) => x.description == 'Rank');
    expect([for (final r in (await cls.getLevels(newAna))[newRank.id]!) r.levelLabel], ['I', 'II']);
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

  // APP Procress 16 part 3a: a module is .ddata (its data) + .dpage (its page)
  group('module files', () {
    ({String name, Uint8List bytes}) file(String name, Object json) => (name: name, bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))));
    Future<int> blocksOf(int id) async => (await db.rawQuery('SELECT COUNT(*) n FROM page_block WHERE module_ref=?', [id])).single['n'] as int;

    test('a module exported as its pair and picked back comes back as a copy, page and all', () async {
      final mods = ModuleDao(db);
      final cast = await mods.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
      await ClassifierDao(db).createItem(moduleRef: cast, name: 'Ana');
      await db.insert('page_block', {'module_ref': cast, 'block_type': 'columns', 'config': jsonEncode({'widths': [8, 4]}), 'block_order': 0});
      final pair = (await Mddx.export(db, nx, cast))!;
      final data = jsonDecode(utf8.decode(pair.data)) as Map, page = jsonDecode(utf8.decode(pair.page)) as Map;
      expect((data['file'], data['fileVersion'], (data['pageBlocks'] as List).length), ('ddata', 1, 0));
      expect((page['file'], (page['modules'] as List).single['name'], (page['pageBlocks'] as List).length), ('dpage', 'Cast', 1));

      final other = await db.insert('nexus', {'name': 'Other'});
      // picked in either order
      final id = await Mddx.import(db, other, null, [(name: 'Cast.dpage', bytes: pair.page), (name: 'Cast.ddata', bytes: pair.data)]);
      expect((await db.rawQuery('SELECT name, nexus_ref FROM module WHERE id=?', [id])).single, {'name': 'Cast', 'nexus_ref': other});
      expect((await db.rawQuery('SELECT name FROM classifier_object WHERE module_ref=?', [id])).single['name'], 'Ana');
      expect(jsonDecode((await db.rawQuery('SELECT config FROM page_block WHERE module_ref=?', [id])).single['config'] as String), {'widths': [8, 4]});

      // the .ddata alone: the data, no page
      final bare = await Mddx.import(db, other, null, [(name: 'Cast.ddata', bytes: pair.data)]);
      expect(await blocksOf(bare!), 0);
    });

    test('a .dpage alone is refused; so is something that is not a module', () async {
      final pair = (await Mddx.export(db, nx, await ModuleDao(db).createModule(nexusRef: nx, name: 'P', kind: ModuleKind.drafter)))!;
      final pageOnly = [(name: 'P.dpage', bytes: pair.page)];
      expect(Mddx.onlyPages(pageOnly), isTrue);
      expect(await Mddx.import(db, nx, null, pageOnly), isNull);
      expect(await Mddx.import(db, nx, null, [(name: 'x.ddata', bytes: Uint8List.fromList('not json'.codeUnits))]), isNull);
    });

    test('an older .mddx (one file, its page inside) still imports', () async {
      final cast = await ModuleDao(db).createModule(nexusRef: nx, name: 'Old', kind: ModuleKind.classifier);
      await db.insert('page_block', {'module_ref': cast, 'block_type': 'text', 'content': 'hi', 'block_order': 0});
      final pair = (await Mddx.export(db, nx, cast))!;
      final joined = Mddx.join(jsonDecode(utf8.decode(pair.data)) as Map<String, Object?>, jsonDecode(utf8.decode(pair.page)) as Map<String, Object?>)
        ..remove('file')
        ..remove('fileVersion');
      final id = await Mddx.import(db, nx, null, [file('Old.mddx', joined)]);
      expect(await blocksOf(id!), 1);
    });

    test('the pair the desktop writes opens here (EXE src/db/module-files.js output)', () async {
      final id = await Mddx.import(db, nx, null, [
        (name: 'Module.ddata', bytes: File('test/fixtures/exe-module.ddata').readAsBytesSync()),
        (name: 'Module.dpage', bytes: File('test/fixtures/exe-module.dpage').readAsBytesSync()),
      ]);
      expect((await db.rawQuery('SELECT name, kind FROM module WHERE id=?', [id])).single, {'name': 'โปรเจกต์ ใหม่', 'kind': 'manager'});
      expect(await blocksOf(id!), 4);
    });
  });
  test('a file already in the Nexus, picked into a folder: filed there if it was unfiled', () async {
    final mods = ModuleDao(db);
    final a = await mods.createModule(nexusRef: nx, name: 'A', kind: ModuleKind.collector);
    final b = await mods.createModule(nexusRef: nx, name: 'B', kind: ModuleKind.collector);
    final bytes = Uint8List.fromList([1, 2, 3]), other = Uint8List.fromList([4, 5]);
    Future<int> row(Uint8List b, int? folder) => db.insert('import_file', {
          'nexus_ref': nx, 'file_name': 'x.png', 'file_path': 'p', 'file_type': 'png', 'file_size': b.length,
          'sha256': sha256.convert(b).toString(), 'module_ref': folder,
        });
    Future<Object?> folderOf(int id) async => (await db.rawQuery('SELECT module_ref FROM import_file WHERE id=?', [id])).single['module_ref'];
    final loose = await row(bytes, null), filed = await row(other, a);
    expect(await AssetStore.addFile(db, nx, 'x.png', bytes, moduleRef: b), loose);
    expect(await folderOf(loose), b);
    expect(await AssetStore.addFile(db, nx, 'y.png', other, moduleRef: b), filed);
    expect(await folderOf(filed), a, reason: 'one already in a folder stays where it is');
  });
  // EXE's kind "page" (SDB 2.1.0): kept as itself, never read back as a folder
  test('a page module survives its module files as kind page, with only what was put on it', () async {
    expect(ModuleKind.fromId('page'), ModuleKind.page);
    expect(defaultPageLayout(ModuleKind.page, null), isEmpty);
    final p = await ModuleDao(db).createModule(nexusRef: nx, name: 'Home', kind: ModuleKind.page);
    final pair = (await Mddx.export(db, nx, p))!;
    final id = await Mddx.import(db, nx, null, [(name: 'Home.ddata', bytes: pair.data), (name: 'Home.dpage', bytes: pair.page)]);
    expect((await db.rawQuery('SELECT kind FROM module WHERE id=?', [id])).single['kind'], 'page');
  });
}
