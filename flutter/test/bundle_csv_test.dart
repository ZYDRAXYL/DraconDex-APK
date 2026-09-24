import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/services/bundle_service.dart';
import 'package:dracondex/data/services/csv_import.dart';

/// Bundles and the guide (V5.md §11.7–§11.8, EXE db/bundle.js) built from
/// the vendored SDB templates, and CSV → Classifier (§11.10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('the English guide lands with the desktop\'s 19 links, 1 dangling', () async {
    final spec = await BundleService.loadGuide('en');
    final r = await BundleService.create(db, nx, null, spec);
    expect(r.folderId, isNotNull);
    expect(r.managerId, isNotNull);
    final links = await db.rawQuery('SELECT target_key FROM wiki_link WHERE nexus_ref=?', [nx]);
    expect(links.length, 19);
    expect(links.where((l) => l['target_key'] == null).length, 1);
    // The Manager's page is the project page, laid out already.
    final blocks = await db.rawQuery('SELECT component FROM page_block WHERE module_ref=? ORDER BY block_order', [r.managerId]);
    expect(blocks.first['component'], 'core.properties');
    expect(blocks[1]['component'], 'manager.view');
    expect(blocks.last['component'], 'core.related');
  });

  test('every genre bundle builds in every shipped locale', () async {
    for (final loc in ['en', 'th', 'ja', 'qd']) {
      for (final b in await BundleService.loadBundles(loc)) {
        final spec = {...(b['spec'] as Map<String, dynamic>), 'name': b['name']};
        final r = await BundleService.create(db, nx, null, spec);
        expect(r.moduleIds, isNotEmpty, reason: '${b['id']} / $loc');
      }
    }
    final names = await db.rawQuery("SELECT name FROM module WHERE kind='collector'");
    expect(names.map((r) => r['name']).toSet().length, greaterThan(4), reason: 'names resolved per locale');
    expect(names.any((r) => '${r['name']}'.startsWith('bundle')), isFalse, reason: 'no raw string keys');
  });

  group('CSV', () {
    test('decodes UTF-8 with a BOM, and windows-874 Thai', () {
      expect(CsvImport.decode(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('ชื่อ')])), ('ชื่อ', 'utf-8'));
      // "ก" is 0xA1 in windows-874 and not valid UTF-8 on its own.
      expect(CsvImport.decode(Uint8List.fromList([0xA1, 0x2C, 0x41])), ('ก,A', 'windows-874'));
    });

    test('parses quotes and the delimiter, guesses types', () {
      final c = CsvImport.read(Uint8List.fromList(utf8.encode(
          'Name;HP;Alive;Born;Bio\n"Ana; the bold";12;yes;1990-02-03;"Said ""hi"""\nBram;1,200;no;1991-1-1;x\n\n')));
      expect(c.header, ['Name', 'HP', 'Alive', 'Born', 'Bio']);
      expect(c.rows.first, ['Ana; the bold', '12', 'yes', '1990-02-03', 'Said "hi"']);
      expect(c.types, ['name', 'number', 'checkbox', 'date', 'text']);
      final spec = CsvImport.spec('People', c, c.types);
      final obj = ((spec['modules'] as List).first['objects'] as List).first as Map;
      expect(obj['values'], {'HP': '12', 'Alive': true, 'Born': '3/2/1990', 'Bio': 'Said "hi"'});
    });

    test('builds one Classifier with no folder', () async {
      final c = CsvImport.read(Uint8List.fromList(utf8.encode('Name,HP,HP\nAna,1,2\nBram,3,4\n')));
      final r = await BundleService.create(db, nx, null, CsvImport.spec('Cast', c, c.types));
      expect(r.folderId, isNull);
      expect(r.managerId, isNull);
      final fields = await db.rawQuery('SELECT description FROM classifier_template WHERE module_ref=?', [r.moduleIds.single]);
      expect(fields.map((f) => f['description']), ['HP', 'HP (2)']);
      expect((await db.rawQuery('SELECT COUNT(*) AS n FROM classifier_attribute')).single['n'], 4);
    });
  });
}
