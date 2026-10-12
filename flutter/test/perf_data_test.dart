import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/database/vault_upgrade.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/page_block_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/bundle_service.dart';
import 'package:dracondex/data/services/csv_import.dart';
import 'package:dracondex/data/services/search_service.dart';
import 'package:dracondex/data/services/snapshot_codec.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';
import 'package:dracondex/features/page/views/classifier_views.dart';
import 'package:dracondex/providers/db_providers.dart';

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

    // Procress 19 part 8: the numbers part 3-4 reached become ceilings, about
    // three times what they measure on a Linux CI container, so CI noise
    // passes and a regression to the old shape (row-by-row inserts, a full
    // reload per keystroke, a table scan) fails.
    final over = <String>[];
    void budget(String what, num value, num max) {
      if (value > max) over.add('$what: ${value.toStringAsFixed(1)} > $max');
    }

    // ── import ───────────────────────────────────────────────────────────
    var sw = Stopwatch()..start();
    final text = File('test/fixtures/stress-v2.json').readAsStringSync();
    final fixture = jsonDecode(text) as Map<String, Object?>;
    final decode = sw.elapsedMilliseconds;
    sw = Stopwatch()..start();
    final viaCodec = await SnapshotCodec.decode(Uint8List.fromList(utf8.encode(text)));
    final decodeBg = sw.elapsedMilliseconds;
    expect(viaCodec, fixture);
    sw = Stopwatch()..start();
    final r = await VaultSnapshotService.applySnapshot(db, nexusId, fixture);
    expect(r.ok, isTrue, reason: r.code);
    row('decode stress-v2.json (${(text.length / 1024).round()} KB), in place', '$decode ms', 'what the UI isolate paid');
    row('  the same through SnapshotCodec (wall)', '$decodeBg ms', 'on a background isolate (part 4)');
    row('import snapshot (520 modules, 3,000 objects)', '${sw.elapsedMilliseconds} ms', 'batched inserts (part 4)');
    budget('import snapshot', sw.elapsedMilliseconds, 1000); // was ~2,000 row by row

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
    final nestAll = await time(() async {
      for (final f in top.where((m) => m.kind == ModuleKind.collector)) {
        await modules.getModules(nexusId, f.id);
      }
    });
    row('Nest: all 20 folders expanded', ms(nestAll), '< 50 ms');
    budget('Nest: all 20 folders', nestAll, 50);

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
    row('one value write + whole reload (before F3)', ms(write + whole), '(what a keystroke paid)');

    // ── the same, through the providers the Classifier view watches (F3) ──
    final c = ProviderContainer(overrides: [databaseProvider.overrideWith((ref) async => db)]);
    addTearDown(c.dispose);
    c.listen(clsDataProvider(clsId), (_, _) {});
    sw = Stopwatch()..start();
    await c.read(clsDataProvider(clsId).future);
    row('Classifier: clsDataProvider first load', ms(sw.elapsedMicroseconds / 1000), '< 300 ms');
    budget('clsDataProvider first load', sw.elapsedMicroseconds / 1000, 300);
    final viaProviders = await time(() async {
      await c.read(clsValuesProvider(clsId).notifier).set(items[1500].id, age, 'p${n++}');
      await c.read(clsDataProvider(clsId).future);
    }, runs: 9);
    row('one value write, patched in place (F3)', ms(viaProviders), '< 16 ms');
    budget('one value write through the providers', viaProviders, 16); // was ~20 with a full reload

    // ── a CSV-sized Classifier through BundleService (part 4) ─────────────
    final csv = CsvRead('utf-8', ['Name', 'Age', 'Note'],
        [for (var i = 0; i < 3000; i++) ['Row $i', '$i', 'note $i']], const ['text', 'number', 'text'], false);
    sw = Stopwatch()..start();
    await BundleService.create(db, nexusId, null, CsvImport.spec('CSV', csv, const ['text', 'number', 'text']));
    row('CSV import: 3,000 rows x 2 fields', '${sw.elapsedMilliseconds} ms', 'batched inserts (part 4)');
    budget('CSV import', sw.elapsedMilliseconds, 1000); // was ~2,000 row by row

    // ── search: the FTS index is built by the first 3-char query ─────────
    final search = SearchService(db);
    sw = Stopwatch()..start();
    await search.content('Row 29');
    row('search: first content query (builds FTS)', '${sw.elapsedMilliseconds} ms', search.usingFts ? 'trigram' : 'LIKE (no fts5)');
    row('search: next query', ms(await time(() => search.content('note 12'))), '');

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
    expect(over, isEmpty, reason: 'over budget');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
