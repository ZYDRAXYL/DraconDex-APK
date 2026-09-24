import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/models/viewer_model.dart';
import 'package:dracondex/data/services/search_service.dart';

/// The APK V3 search (APP docs/APK-V3.md §9.2) against the real vault schema,
/// on both content paths: the LIKE scan every phone has, and the temp FTS5
/// trigram index when the SQLite underneath can build one.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  Future<Database> openVault() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return db;
  }

  /// Two Nexuses, so "across every Nexus" and "this Nexus only" differ.
  Future<({int world, int other, int chars, int aria, int chapter})> seed(Database db) async {
    final world = await db.insert('nexus', {'name': 'World'});
    final other = await db.insert('nexus', {'name': 'Other'});
    final chars = await db.insert('module', {
      'nexus_ref': world, 'name': 'Characters', 'kind': 'classifier',
      'description': 'Everyone who walks the Silver Road.', 'handle': 'cast',
    });
    final book = await db.insert('module', {'nexus_ref': world, 'name': 'Book', 'kind': 'author'});
    await db.insert('module', {'nexus_ref': other, 'name': 'Silver Mine', 'kind': 'collector'});
    final aria = await db.insert('classifier_object', {
      'module_ref': chars, 'name': 'Aria', 'note': 'ผู้นำของกองคาราวาน',
    });
    final tpl = await db.insert('classifier_template', {
      'module_ref': chars, 'object_ref': aria, 'description': 'Weapon',
      'attribute_type': 'text', 'levelable': 0, 'has_condition': 0, 'display_order': 0,
    });
    await db.insert('classifier_attribute', {'object_ref': aria, 'template_ref': tpl, 'attribute_value': 'a silver spear'});
    final chapter = await db.insert('book_chapter', {
      'module_ref': book, 'name': 'Chapter One', 'chapter_content': 'The road was 100% silver.',
    });
    await db.insert('page_block', {
      'module_ref': chars, 'item_key': 'cobj_$aria', 'block_type': 'text', 'content': 'Born under a comet.',
    });
    // The shared element layout is a template, not anybody's text.
    await db.insert('page_block', {
      'module_ref': chars, 'item_key': '*', 'block_type': 'text', 'content': 'comet template',
    });
    return (world: world, other: other, chars: chars, aria: aria, chapter: chapter);
  }

  group('things', () {
    test('match names across every Nexus, prefix first', () async {
      final db = await openVault();
      await seed(db);
      final hits = await SearchService(db).things('sil');
      expect(hits.map((h) => h.title), ['Silver Mine']);
      final ch = await SearchService(db).things('ch');
      expect(ch.map((h) => h.title), ['Characters', 'Chapter One']);
    });

    test('stay inside one Nexus when asked', () async {
      final db = await openVault();
      final s = await seed(db);
      expect(await SearchService(db).things('silver', nexusId: s.world), isEmpty);
    });

    test('@ matches handles, and a hit knows where it goes', () async {
      final db = await openVault();
      final s = await seed(db);
      final hits = await SearchService(db).things('@ca');
      expect(hits.single.location, '/hub/${s.world}/module/${s.chars}');
      final aria = (await SearchService(db).things('aria')).single;
      expect(aria.location, '/hub/${s.world}/module/${s.chars}/item/cobj_${s.aria}');
    });
  });

  group('rankItems', () {
    IndexedItem item(String name) => IndexedItem(
          key: 'module_1', itemKind: 'module', name: name, moduleId: 1,
          moduleName: name, moduleKind: 'collector', tags: const []);

    test('loose accepts the letters in order, strict does not', () {
      final items = [item('Characters'), item('Chapter')];
      expect(SearchService.rankItems(items, 'crs'), isEmpty);
      expect(SearchService.rankItems(items, 'crs', loose: true).map((i) => i.name), ['Characters']);
    });

    test('a typed path matches on its last segment', () {
      final items = [item('Characters'), item('World')];
      expect(SearchService.rankItems(items, 'World / Char').map((i) => i.name), ['Characters']);
    });
  });

  for (final fts in [false, null]) {
    group(fts == false ? 'content via LIKE' : 'content via FTS when available', () {
      test('finds descriptions, fields, chapters and element blocks', () async {
        final db = await openVault();
        final s = await seed(db);
        final service = SearchService(db, useFts: fts);
        final hits = await service.content('silver');
        expect(hits.map((h) => h.key).toSet(),
            {'module_${s.chars}', 'cobj_${s.aria}', 'bchp_${s.chapter}'});
        final comet = await service.content('comet');
        expect(comet.single.key, 'cobj_${s.aria}');
        expect(comet.single.title, 'Aria');
        expect(comet.single.snippet, contains('comet'));
        if (fts == null) {
          // Not asserted: the SQLite under the test may lack fts5 or trigram,
          // and then this group is the LIKE path again — which is the point.
          // ignore: avoid_print
          print('content search ran on ${service.usingFts ? 'FTS5 trigram' : 'LIKE (no fts5/trigram here)'}');
        }
      });

      test('Thai text, and one Nexus only', () async {
        final db = await openVault();
        final s = await seed(db);
        final service = SearchService(db, useFts: fts);
        expect((await service.content('คาราวาน')).single.key, 'cobj_${s.aria}');
        expect(await service.content('silver', nexusId: s.other), isEmpty);
      });

      test('short queries and LIKE wildcards are taken literally', () async {
        final db = await openVault();
        await seed(db);
        final service = SearchService(db, useFts: fts);
        expect((await service.content('0%')).single.title, 'Chapter One');
        expect(await service.content('_x'), isEmpty);
      });
    });
  }

  test('snippetOf centres on the match', () {
    final s = SearchService.snippetOf('${'a' * 100} needle ${'b' * 100}', 'needle', radius: 5);
    expect(s, '…aaaa needle bbbb…');
  });
}
