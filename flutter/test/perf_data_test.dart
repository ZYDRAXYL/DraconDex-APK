import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/database/vault_upgrade.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/page_block_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';

/// Procress 19 part 1 — the data-layer half of the APK's numbers, measured on
/// the stress vault every app is measured on: `test/fixtures/stress-v2.json`,
/// vendored from DraconDex-SDB (`fixtures/`) and written by DraconDex-EXE's
/// serializeVault (520 modules + a Classifier of 3,000 objects / 5,000
/// values). EXE's `electron/test/perf.driver.mjs` builds the same vault.
///
/// What this can measure honestly from the host VM: SQL time and query plans
/// through the app's own DAOs, on sqflite_common_ffi — the same SQLite the
/// desktop build of the app uses. What it cannot: frame times and the
/// platform-channel cost of Android's sqflite. Those are
/// `integration_test/perf_test.dart`, on an emulator or a device.
///
/// Prints a table; asserts only the budgets Procress 19 part 8 set. Run alone:
///   flutter test test/perf_data_test.dart
void main() {
  sqfliteFfiInit();

  test('stress vault: import, Nest, Classifier, one write', () async {
    final dir = await Directory.systemTemp.createTemp('ddx-perf-');
    addTearDown(() => dir.delete(recursive: true));
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/vault.db');
    addTearDown(db.close);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    await VaultUpgrade().run(db);
    // What DatabaseHelper._onOpen runs after the upgrade (SDB @indexes).
    for (final sql in vaultIndexStatements) {
      await db.execute(sql);
    }
    for (final code in defaultColorCodes) {
      await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
    }
    final nexusId = await db.insert('nexus', {'name': 'Stress'});

    final rows = <(String, String, String)>[];
    void row(String what, String value, [String target = '']) {
      rows.add((what, value, target));
    }

    Future<double> time(Future<void> Function() body, {int runs = 5}) async {
      final out = <double>[];
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        await body();
        out.add(sw.elapsedMicroseconds / 1000);
      }
      out.sort();
      return out[out.length ~/ 2];
    }

    String ms(double v) => '${v.toStringAsFixed(1)} ms';

    // ── import ───────────────────────────────────────────────────────────
    var sw = Stopwatch()..start();
    final text = File('test/fixtures/stress-v2.json').readAsStringSync();
    final fixture = jsonDecode(text) as Map<String, Object?>;
    final decode = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    final r = await VaultSnapshotService.applySnapshot(db, nexusId, fixture);
    expect(r.ok, isTrue, reason: r.code);
    row('decode stress-v2.json (${(text.length / 1024).round()} KB)', '$decode ms', 'on the UI isolate today (F6)');
    row('import snapshot (520 modules, 3,000 objects)', '${sw.elapsedMilliseconds} ms', '(F6)');

    final modules = ModuleDao(db);
    final cls = ClassifierDao(db);
    final pages = PageBlockDao(db);
    final top = await modules.getModules(nexusId, null);
    final folder = top.firstWhere((m) => m.name == 'Folder 0');
    final clsId = top.firstWhere((m) => m.kind == ModuleKind.classifier).id;
    expect((await cls.getItems(clsId)).length, 3000);

    // ── Nest ─────────────────────────────────────────────────────────────
    row('Nest: top level (21 rows)', ms(await time(() => modules.getModules(nexusId, null))), '< 16 ms');
    row('Nest: one folder (25 rows)', ms(await time(() => modules.getModules(nexusId, folder.id))), '< 16 ms');
    row('Nest: all 20 folders expanded', ms(await time(() async {
      for (final f in top.where((m) => m.kind == ModuleKind.collector)) {
        await modules.getModules(nexusId, f.id);
      }
    })), '< 50 ms');

    // ── Classifier, the queries clsDataProvider runs ─────────────────────
    row('Classifier: fields', ms(await time(() => cls.getFields(clsId))));
    row('Classifier: 3,000 items', ms(await time(() => cls.getItems(clsId))));
    row('Classifier: 5,000 values', ms(await time(() => cls.getModuleValues(clsId))));
    row('Classifier: relations', ms(await time(() => db.rawQuery(
        "SELECT r.id FROM entity_relation r JOIN classifier_object o ON r.from_key='cobj_'||o.id "
        'WHERE o.module_ref=? ORDER BY r.id', [clsId]))));
    final whole = await time(() async {
      await cls.getFields(clsId);
      await cls.getItems(clsId);
      await cls.getModuleValues(clsId);
      await db.rawQuery(
          "SELECT r.id FROM entity_relation r JOIN classifier_object o ON r.from_key='cobj_'||o.id "
          'WHERE o.module_ref=? ORDER BY r.id', [clsId]);
    });
    row('Classifier: whole clsDataProvider reload', ms(whole), '< 300 ms, and not per keystroke (F3)');
    row('page blocks of the Classifier page', ms(await time(() => pages.props(clsId))), '< 16 ms');

    // ── one write ────────────────────────────────────────────────────────
    final items = await cls.getItems(clsId);
    final age = (await cls.getFields(clsId)).first.id;
    var n = 0;
    final write = await time(() => cls.setValue(objectRef: items[1500].id, templateRef: age, value: 'v${n++}'), runs: 9);
    row('one value write (setValue + wiki reindex)', ms(write), '< 16 ms');
    row('one value write + whole reload (today)', ms(write + whole), '(F3: what a keystroke pays)');

    // ── plans: which hot queries still SCAN a table that grows (F1) ───────
    Future<String> plan(String sql, List<Object?> args) async =>
        (await db.rawQuery('EXPLAIN QUERY PLAN $sql', args)).map((r) => r['detail']).join(' | ');
    final hot = <String, (String, List<Object?>)>{
      'module children': ('SELECT * FROM module m WHERE m.nexus_ref=? AND m.parent_id IS ?', [nexusId, folder.id]),
      'classifier items': ('SELECT * FROM classifier_object WHERE module_ref=?', [clsId]),
      'classifier values': (
        'SELECT a.* FROM classifier_attribute a JOIN classifier_object o ON a.object_ref=o.id WHERE o.module_ref=?',
        [clsId]
      ),
      'page blocks': ('SELECT * FROM page_block WHERE module_ref=? AND item_key IS NULL ORDER BY block_order', [clsId]),
      'backlinks': ('SELECT * FROM entity_relation WHERE to_key=?', ['cobj_1']),
    };
    var scans = 0;
    for (final e in hot.entries) {
      final p = await plan(e.value.$1, e.value.$2);
      final scan = RegExp(r'\bSCAN (\w+)').allMatches(p).map((m) => m.group(1)).toList();
      if (scan.isNotEmpty) scans++;
      row('plan: ${e.key}', scan.isEmpty ? 'index' : 'SCAN ${scan.join(', ')}', 'no SCAN (F1)');
    }

    // ignore: avoid_print
    print([
      '',
      for (final (w, v, t) in rows) '${w.padRight(48)} ${v.padRight(16)} $t',
      '',
    ].join('\n'));
    // F1 is done when none of the hot queries scans a table (SDB holds the
    // same queries to the same rule in test/indexes.test.mjs).
    expect(scans, 0);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
