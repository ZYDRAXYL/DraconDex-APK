import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';

/// The shared snapshot fixture (Procress 12 part 0). `test/fixtures/
/// snapshot-v2.json` is vendored from DraconDex-SDB (`fixtures/`), and was
/// written by DraconDex-EXE's `serializeVault` — the desktop's own test
/// imports the very same file. So this holds the Dart port to exactly what
/// the desktop writes, not to a round trip of its own output.
///
/// Families this app cannot import yet, if any — declared rather than hidden.
/// Empty since APK V3 part 2 ported Diviner, Exhibitor and module presets:
/// every row the desktop wrote must now land.
const notYet = <String>{};

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  test('the desktop-written fixture imports whole', () async {
    final fixture = jsonDecode(File('test/fixtures/snapshot-v2.json').readAsStringSync()) as Map<String, Object?>;
    expect(fixture['version'], 2);

    final db = await factory.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    for (final code in defaultColorCodes) {
      await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
    }
    final nexusId = await db.insert('nexus', {'name': 'Target'});

    final r = await VaultSnapshotService.applySnapshot(db, nexusId, fixture);
    expect(r.ok, isTrue, reason: r.code);

    bool missing(Object? key) => key is String && notYet.contains(key.split('_').first);
    List<Map> list(Object? v) => (v as List).cast<Map>();
    Future<int> count(String sql) async => (await db.rawQuery(sql)).first['c']! as int;

    expect(await count('SELECT COUNT(*) AS c FROM module WHERE nexus_ref=$nexusId'),
        list(fixture['modules']).length);
    expect(await count('SELECT COUNT(*) AS c FROM page_block'), list(fixture['pageBlocks']).length);
    // The sections the port added in part 2 come across whole too.
    final dvn = fixture['diviner'] as Map;
    expect(await count('SELECT COUNT(*) AS c FROM diviner_table'), list(dvn['tables']).length);
    expect(await count('SELECT COUNT(*) AS c FROM diviner_entry'), list(dvn['entries']).length);
    final exh = fixture['exhibitor'] as Map;
    expect(await count('SELECT COUNT(*) AS c FROM exhibit_node'), list(exh['nodes']).length);
    expect(await count('SELECT COUNT(*) AS c FROM module_preset'), list(fixture['modulePresets']).length);

    final rels = list(fixture['relations']);
    final relGap = rels.where((e) => missing(e['fromKey']) || missing(e['toKey'])).length;
    expect(r.droppedRelations, relGap);
    expect(await count('SELECT COUNT(*) AS c FROM entity_relation'), rels.length - relGap);

    final pins = list((fixture['sketcher'] as Map)['pins']);
    final pinGap = pins.where((p) => missing(p['linkerKey'])).length;
    expect(r.droppedPins, pinGap);
    expect(await count('SELECT COUNT(*) AS c FROM sketch_pin'), pins.length - pinGap);

    final nodes = list((fixture['designer'] as Map)['nodes']).where((n) => n['linkerKey'] != null);
    final nodeGap = nodes.where((n) => missing(n['linkerKey'])).length;
    expect(await count('SELECT COUNT(*) AS c FROM design_node WHERE linker_key IS NOT NULL'),
        nodes.length - nodeGap);

    // Every key that did land points at a row that exists here.
    const tables = <String, String>{
      'module': 'module', 'cobj': 'classifier_object', 'bchp': 'book_chapter', 'chss': 'chat_session',
      'tlev': 'timeline_event', 'sdlg': 'story_dialogue', 'skpg': 'sketch_page', 'ctpl': 'classifier_template',
      'note': 'note', 'divt': 'diviner_table',
    };
    Future<bool> exists(String key) async {
      final m = RegExp(r'^([a-z]+)_(\d+)$').firstMatch(key);
      final table = m == null ? null : tables[m.group(1)];
      if (table == null) return false;
      return (await db.rawQuery('SELECT 1 FROM $table WHERE id=?', [int.parse(m!.group(2)!)])).isNotEmpty;
    }
    for (final row in await db.rawQuery('SELECT from_key, to_key FROM entity_relation')) {
      expect(await exists(row['from_key']! as String), isTrue, reason: '${row['from_key']}');
      expect(await exists(row['to_key']! as String), isTrue, reason: '${row['to_key']}');
    }
    for (final row in await db.rawQuery('SELECT linker_key FROM sketch_pin')) {
      expect(await exists(row['linker_key']! as String), isTrue, reason: '${row['linker_key']}');
    }
    final shared = await db.rawQuery("SELECT 1 FROM page_block WHERE item_key='*'");
    expect(shared, isNotEmpty, reason: 'the shared element layout');

    // The other half of the contract: what this app WRITES has the desktop's
    // shape — every section, and every field of every row. A field the
    // desktop added and this serializer does not select would pass every
    // import test above and still lose data on the way back.
    final ours = (await VaultSnapshotService.serializeVault(db, nexusId))!;
    Set<String>? fieldsOf(Object? rows) =>
        rows is List && rows.isNotEmpty ? (rows.first as Map).keys.cast<String>().toSet() : null;
    expect(ours.keys.toSet(), fixture.keys.toSet(), reason: 'top-level sections');
    for (final section in fixture.keys) {
      final theirs = fixture[section];
      final mine = ours[section];
      if (theirs is List) {
        final f = fieldsOf(theirs);
        if (f != null) expect(fieldsOf(mine), f, reason: section);
      } else if (theirs is Map && section != 'nexus') {
        expect((mine as Map).keys.toSet(), theirs.keys.toSet(), reason: section);
        for (final sub in theirs.keys) {
          final f = fieldsOf(theirs[sub]);
          if (f != null) expect(fieldsOf(mine[sub]), f, reason: '$section.$sub');
        }
      }
    }
  });
}
