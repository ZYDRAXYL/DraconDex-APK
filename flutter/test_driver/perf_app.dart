// Procress 19 part 1 — the device half of the APK's numbers. The app target
// `flutter drive` builds and installs; test_driver/perf_test.dart drives it.
//
// The real DraconDexApp on Android's own sqflite (platform channel and all),
// with a throwaway vault the driver fills from test/fixtures/stress-v2.json
// — the same 520 modules + Classifier of 3,000 objects / 5,000 values that
// test/perf_data_test.dart and EXE's perf.driver.mjs use. The fixture comes
// over the driver connection because it is not an asset: shipping 650 KB of
// test data in every release APK is not the trade.
//
// Not part of `flutter test` or the app build. Run:
//   flutter drive --profile --driver=test_driver/perf_test.dart --target=test_driver/perf_app.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dracondex/app.dart';
import 'package:dracondex/core/database/db_factory.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/database/vault_upgrade.dart';
import 'package:dracondex/core/router/app_router.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/services/snapshot_codec.dart';
import 'package:dracondex/data/services/update_service.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';
import 'package:dracondex/features/page/page_providers.dart';
import 'package:dracondex/features/page/views/classifier_views.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/providers/update_provider.dart';

final _fixture = StringBuffer();
final _db = Completer<Database>();
late final ProviderContainer _c;
late Database _vault;
int _cls = 0, _item = 0, _field = 0, _n = 0;

void main() {
  enableFlutterDriverExtension(handler: _handle);
  configureDatabaseFactory();
  _c = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) => _db.future),
    updateCheckProvider.overrideWith((ref) async => const UpdateCheckResult(available: false, dismissed: false, current: '0')),
    appVersionProvider.overrideWith((ref) async => '0'),
  ]);
  runApp(UncontrolledProviderScope(container: _c, child: const DraconDexApp()));
}

Future<String> _handle(String? msg) async {
  final m = msg ?? '';
  final i = m.indexOf(':');
  final cmd = i < 0 ? m : m.substring(0, i);
  final arg = i < 0 ? '' : m.substring(i + 1);
  switch (cmd) {
    case 'chunk':
      _fixture.write(arg);
      return 'ok';
    case 'import':
      return jsonEncode(await _import());
    case 'go':
      appRouter.go(arg);
      return 'ok';
    case 'preset':
      // the Classifier page's one view block, as the view-mode button sets it
      await _vault.rawUpdate(
          "UPDATE page_block SET config=? WHERE module_ref=? AND component='classifier.view'",
          [jsonEncode({'preset': arg}), _cls]);
      _c.invalidate(pageProvider);
      return 'ok';
    case 'set':
      // one value, through the provider the Classifier view watches (F3)
      final sw = Stopwatch()..start();
      await _c.read(clsValuesProvider(_cls).notifier).set(_item, _field, 'v${_n++}');
      return '${sw.elapsedMicroseconds / 1000}';
  }
  return 'unknown: $cmd';
}

Future<Map<String, Object?>> _import() async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/ddx-perf.db';
  for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
    if (File(f).existsSync()) File(f).deleteSync();
  }
  final db = await openDatabase(path);
  await db.execute('PRAGMA foreign_keys = ON');
  // The steps DatabaseHelper._onOpen runs on every open, timed apart; the
  // second pass is what a start on an existing vault pays (all IF NOT EXISTS).
  final open = <String, int>{};
  final sw = Stopwatch()..start();
  for (final pass in const ['first', 'again']) {
    sw.reset();
    await VaultUpgrade.createTables(db);
    open['${pass}CreateMs'] = sw.elapsedMilliseconds;
    sw.reset();
    await VaultUpgrade().run(db);
    open['${pass}UpgradeMs'] = sw.elapsedMilliseconds;
    sw.reset();
    final failed = await VaultUpgrade.createIndexes(db);
    if (failed.isNotEmpty) throw StateError(failed.join('\n'));
    open['${pass}IndexMs'] = sw.elapsedMilliseconds;
  }
  for (final code in defaultColorCodes) {
    await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
  }
  final nexus = await db.insert('nexus', {'name': 'Stress'});

  final bytes = Uint8List.fromList(utf8.encode(_fixture.toString()));
  sw.reset();
  final payload = await SnapshotCodec.decode(bytes);
  final decode = sw.elapsedMilliseconds;
  sw.reset();
  final r = await VaultSnapshotService.applySnapshot(db, nexus, payload);
  final apply = sw.elapsedMilliseconds;
  if (!r.ok) throw StateError('import failed: ${r.code}');

  _vault = db;
  _cls = (await db.rawQuery("SELECT id FROM module WHERE nexus_ref=? AND kind='classifier'", [nexus])).first['id']! as int;
  final dao = ClassifierDao(db);
  _item = (await dao.getItems(_cls))[1500].id;
  _field = (await dao.getFields(_cls)).first.id;
  final folder = (await db.rawQuery(
      "SELECT id FROM module WHERE nexus_ref=? AND name='Folder 0'", [nexus])).first['id']! as int;
  _db.complete(db);
  return {
    'nexus': nexus,
    'classifier': _cls,
    'folder': folder,
    'kb': bytes.length ~/ 1024,
    'statements': vaultCreateStatements.length + vaultIndexStatements.length,
    ...open,
    'decodeMs': decode,
    'applyMs': apply,
  };
}
