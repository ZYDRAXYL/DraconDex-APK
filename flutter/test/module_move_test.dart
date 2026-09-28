import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/module_parents.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';

/// Sorting modules into folders (APP docs/ASSET-PACK.md §1): moveModule is
/// EXE db/module.js moveModule — one call reparents and rewrites the new
/// siblings' order — and nothing can go into a non-Collector or into itself.
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

  Future<List<String>> namesUnder(ModuleDao dao, int nx, int? parent) async =>
      [for (final m in await dao.getModules(nx, parent)) m.name];

  test('a move lands after the siblings there; with an order it takes that order', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'World'});
    final dao = ModuleDao(db);
    final art = await dao.createModule(nexusRef: nx, name: 'Art', kind: ModuleKind.collector);
    final a = await dao.createModule(nexusRef: nx, parentId: art, name: 'A', kind: ModuleKind.drafter);
    await dao.createModule(nexusRef: nx, parentId: art, name: 'B', kind: ModuleKind.drafter);
    final c = await dao.createModule(nexusRef: nx, name: 'C', kind: ModuleKind.inspector);

    await dao.moveModule(c, nexusRef: nx, newParentId: art);
    expect(await namesUnder(dao, nx, art), ['A', 'B', 'C']);
    expect(await namesUnder(dao, nx, null), ['Art']);

    final ids = [for (final m in await dao.getModules(nx, art)) m.id];
    await dao.moveModule(a, nexusRef: nx, newParentId: art, orderedSiblingIds: [ids[2], ids[0], ids[1]]);
    expect(await namesUnder(dao, nx, art), ['C', 'A', 'B']);

    await dao.shiftModule(a, 1);
    expect(await namesUnder(dao, nx, art), ['C', 'B', 'A']);
    await dao.shiftModule(a, 1); // already last: nothing happens
    expect(await namesUnder(dao, nx, art), ['C', 'B', 'A']);
    await dao.shiftModule(c, -1); // already first
    expect(await namesUnder(dao, nx, art), ['C', 'B', 'A']);
  });

  test('never into a non-Collector, never into itself or its own subtree', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'World'});
    final dao = ModuleDao(db);
    final outer = await dao.createModule(nexusRef: nx, name: 'Outer', kind: ModuleKind.collector);
    final inner = await dao.createModule(nexusRef: nx, parentId: outer, name: 'Inner', kind: ModuleKind.collector);
    final cast = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);

    expect(() => dao.moveModule(outer, nexusRef: nx, newParentId: cast), throwsA(isA<ModuleParentError>()));
    expect(() => dao.moveModule(outer, nexusRef: nx, newParentId: outer), throwsA(isA<ModuleParentError>()));
    expect(() => dao.moveModule(outer, nexusRef: nx, newParentId: inner), throwsA(isA<ModuleParentError>()));

    // A multi-select move does what it can: Cast goes in, Outer cannot go
    // inside its own child and is handed back.
    final skipped = await dao.moveModules([outer, cast], nexusRef: nx, newParentId: inner);
    expect(skipped, [outer]);
    expect(await namesUnder(dao, nx, inner), ['Cast']);
    expect((await dao.getModule(outer))!.parentId, isNull);

    // And out again, to the top level.
    await dao.moveModules([cast], nexusRef: nx, newParentId: null);
    expect(await namesUnder(dao, nx, null), ['Outer', 'Cast']);
  });
}
