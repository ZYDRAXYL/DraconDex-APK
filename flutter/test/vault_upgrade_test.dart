import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/database/vault_upgrade.dart';

import 'fixtures/vault_schema_v4.dart';

/// An install from before SDB 2.0 has v4 tables that `CREATE TABLE IF NOT
/// EXISTS` never touches again. VaultUpgrade must bring them to the vendored
/// schema without losing a row or a foreign key (APP docs/APK-V3.md §2).
void main() {
  sqfliteFfiInit();

  Future<Database> openV4() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatementsV4) {
      await db.execute(sql);
    }
    return db;
  }

  /// What DatabaseHelper._onOpen does: new tables first, then the upgrade.
  Future<VaultUpgrade> open(Database db) async {
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    final up = VaultUpgrade();
    await up.run(db);
    return up;
  }

  Future<Set<String>> cols(Database db, String t) async =>
      {for (final r in await db.rawQuery('PRAGMA table_info($t)')) r['name'] as String};

  test('a v4 vault reaches the vendored schema, rows and links intact', () async {
    final db = await openV4();
    final nx = await db.insert('nexus', {'name': 'World'});
    final viewer = await db.insert('module', {'nexus_ref': nx, 'name': 'Cast list', 'kind': 'viewer'});
    final conn = await db.insert('module', {'nexus_ref': nx, 'name': 'Web', 'kind': 'connector'});
    final folder = await db.insert('module', {'nexus_ref': nx, 'name': 'Folder', 'kind': 'collector'});
    final book = await db.insert('module', {'nexus_ref': nx, 'parent_id': folder, 'name': 'Book', 'kind': 'author'});
    await db.insert('module_ui', {'module_ref': conn, 'ui_key': 'activeView', 'ui_value': 'edgelist'});
    await db.insert('module_ui', {'module_ref': viewer, 'ui_key': 'activeView', 'ui_value': 'cards'});
    final ch = await db.insert('book_chapter', {'module_ref': book, 'name': 'One'});
    // The old UNIQUE let NULL labels repeat.
    for (var i = 0; i < 2; i++) {
      await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'module_$book', 'to_key': 'bchp_$ch'});
    }
    await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'module_$book', 'to_key': 'module_$folder', 'label': 'in'});

    final up = await open(db);
    expect(up.log, containsAll(['rebuilt module', 'rebuilt entity_relation']));

    // The kind CHECK is the v5 one, and the data followed it.
    final kinds = {for (final r in await db.rawQuery('SELECT id, kind FROM module')) r['id']: r['kind']};
    expect(kinds[viewer], 'exhibitor');
    expect(kinds[conn], 'exhibitor');
    await db.insert('module', {'nexus_ref': nx, 'name': 'Dice', 'kind': 'diviner'});
    expect(() => db.insert('module', {'nexus_ref': nx, 'name': 'Old', 'kind': 'viewer'}), throwsA(isA<DatabaseException>()));
    final ui = {
      for (final r in await db.rawQuery('SELECT module_ref, ui_key, ui_value FROM module_ui'))
        '${r['module_ref']}.${r['ui_key']}': r['ui_value'],
    };
    expect(ui['$conn.activeView'], 'edges');
    expect(ui['$conn.seedScene'], '1');
    expect(ui['$viewer.activeView'], 'cards');

    // Columns v5 added are there; the rows kept their ids, so every key and
    // foreign key still points at the same thing.
    expect(await cols(db, 'book_chapter'), containsAll(['synopsis', 'status', 'pov_key']));
    expect(await cols(db, 'design_node'), containsAll(['w', 'h', 'read_order']));
    expect(await cols(db, 'classifier_template'), contains('options'));
    expect(await cols(db, 'entity_relation'), containsAll(['rel_type', 'directed', 'module_ref', 'valid_from']));
    final chapter = await db.rawQuery('SELECT module_ref FROM book_chapter WHERE id=?', [ch]);
    expect(chapter.single['module_ref'], book);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect((await db.rawQuery('SELECT COUNT(*) AS n FROM entity_relation')).single['n'], 2);

    // Deleting the parent still cascades: the rebuilt module table kept its
    // place in every other table's foreign keys.
    await db.delete('module', where: 'id=?', whereArgs: [folder]);
    expect(await db.rawQuery('SELECT id FROM book_chapter'), isEmpty);
  });

  test('a second open has nothing to do, and a fresh vault needs nothing', () async {
    final db = await openV4();
    await open(db);
    expect((await open(db)).log, isEmpty);

    final fresh = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => fresh.close());
    expect((await open(fresh)).log, isEmpty);
  });

  test('ALTER-able columns are told apart from the ones that need a rebuild', () {
    expect(VaultUpgrade.alterable('synopsis TEXT'), isTrue);
    expect(VaultUpgrade.alterable('directed INTEGER NOT NULL DEFAULT 1'), isTrue);
    expect(VaultUpgrade.alterable("create_at TEXT NOT NULL DEFAULT (datetime('now'))"), isFalse);
    expect(VaultUpgrade.alterable('w REAL NOT NULL'), isFalse);
    expect(VaultUpgrade.columnDefs('module').keys, containsAll(['id', 'kind', 'handle']));
  });
}
