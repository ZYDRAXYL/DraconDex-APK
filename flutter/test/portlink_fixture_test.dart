// Port Link 9.4 — the merge cases shared with EXE (SDB
// fixtures/portlink-merge-v1.json, vendored to test/fixtures/), run through
// this app's engine. Both engines pass the same cases or one of them has a
// bug: a merge rule changes in SDB first, never here.
import 'dart:convert';
import 'dart:io';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/services/portlink/portlink_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final f = databaseFactoryFfi;
  final fx = jsonDecode(File('test/fixtures/portlink-merge-v1.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = fx['cases'] as List;
  late Directory dir;
  setUpAll(() async => dir = await Directory.systemTemp.createTemp('portfx'));
  tearDownAll(() => dir.delete(recursive: true));

  test('the fixture is the version this runner reads', () {
    expect(fx['format'], 'dracondex-portlink-merge-fixture');
    expect(fx['version'], 1);
  });

  for (final c in cases.cast<Map<String, dynamic>>()) {
    test('${c['name']} — ${c['why']}', () async {
      // Seeded ONCE, then copied: in real use the base and both sides start as
      // copies of one file (SDB fixtures/README.md — separate seeds give the
      // datetime('now') defaults different seconds).
      final at = await Directory('${dir.path}/${c['name']}').create();
      final seed = await f.openDatabase('${at.path}/b', options: OpenDatabaseOptions(singleInstance: false));
      for (final s in vaultCreateStatements) {
        await seed.execute(s);
      }
      for (final s in [...fx['seed'] as List, ...(c['seedExtra'] as List? ?? const [])]) {
        await seed.execute(s as String);
      }
      await seed.close();
      File('${at.path}/b').copySync('${at.path}/l');
      File('${at.path}/b').copySync('${at.path}/w');
      Future<Database> open(String n) async {
        final db = await f.openDatabase('${at.path}/$n', options: OpenDatabaseOptions(singleInstance: false));
        await db.execute('PRAGMA foreign_keys = ON');
        return db;
      }

      final b = await open('b'), l = await open('l'), w = await open('w');
      try {
        for (final s in c['local'] as List) {
          await l.execute(s as String);
        }
        for (final s in c['drive'] as List) {
          await w.execute(s as String);
        }
        final r = await mergeInto(b, l, w, choices: {for (final e in ((c['choices'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'});
        final ex = c['expect'] as Map<String, dynamic>;
        if (ex['code'] == 'needs_choice') {
          expect(r.conflicts.map((x) => x.key).toList()..sort(), [...ex['conflicts'] as List]..sort());
          return;
        }
        expect(r.conflicts.map((x) => x.key), isEmpty, reason: 'no conflict left unanswered');
        for (final q in (ex['queries'] as List).cast<Map<String, dynamic>>()) {
          expect(await w.rawQuery(q['sql'] as String), q['rows'], reason: q['sql'] as String);
        }
        expect(await w.rawQuery('PRAGMA foreign_key_check'), isEmpty, reason: 'nothing points nowhere');
      } finally {
        for (final db in [b, l, w]) {
          await db.close();
        }
      }
    });
  }
}
