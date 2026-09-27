import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/data/services/bundle_service.dart';
import 'package:dracondex/data/services/page_template_service.dart';

/// "Save as Artisan bundle…" and "Adjust first" on the phone (Procress 14
/// part 4, APP docs/TEMPLATES.md §4.4; EXE db/bundle-capture.js and
/// hub/bundles.js submitBundleAdjust): a folder captured from one project
/// builds the same project again, and trimming a module takes everything
/// that pointed at it along.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
  });
  tearDown(() => db.close());

  Future<Map<String, dynamic>> ttrpg() async {
    final b = (await BundleService.loadBundles('en')).firstWhere((b) => b['id'] == 'ttrpg');
    return {...(b['spec'] as Map<String, dynamic>), 'name': b['name']};
  }

  Future<int> count(String sql, int nx) async => (await db.rawQuery(sql, [nx])).first['n'] as int;
  const mods = "SELECT COUNT(*) AS n FROM module WHERE nexus_ref=? AND kind<>'collector'";
  const objs = 'SELECT COUNT(*) AS n FROM classifier_object o JOIN module m ON m.id=o.module_ref WHERE m.nexus_ref=?';
  const pages = 'SELECT COUNT(*) AS n FROM page_block b JOIN module m ON m.id=b.module_ref WHERE m.nexus_ref=?';
  const links = "SELECT COUNT(*) AS n FROM entity_relation r JOIN classifier_object o ON r.from_key='cobj_'||o.id JOIN module m ON m.id=o.module_ref WHERE m.nexus_ref=?";

  test('capture → create builds the same project: modules, keyed fields, pages, samples, links, home', () async {
    final nx = await db.insert('nexus', {'name': 'A'});
    final made = await BundleService.create(db, nx, null, await ttrpg());
    final spec = await BundleService.capture(db, made.folderId!, samples: true);

    expect((spec['folders'] as List).first, {'ref': 'root', 'name': 'TTRPG campaign'});
    expect(spec['home'], isNotNull, reason: 'the first Manager is the home');
    final ms = (spec['modules'] as List).cast<Map<String, dynamic>>();
    expect(ms.length, await count(mods, nx));
    for (final m in ms.where((m) => m['kind'] == 'classifier')) {
      expect((m['fields'] as List).every((f) => (f as Map)['key'] is String), isTrue, reason: '${m['name']}: every field keyed');
      expect(((m['objects'] as List?) ?? const []).length, lessThanOrEqualTo(BundleService.maxSamples));
      expect(((m['objects'] as List?) ?? const []).every((o) => (o as Map)['sample'] == true), isTrue);
    }
    expect(ms.where((m) => m['page'] != null), isNotEmpty);

    final nx2 = await db.insert('nexus', {'name': 'B'});
    final again = await BundleService.create(db, nx2, null, spec);
    expect(again.homeId, isNotNull);
    expect(await count(mods, nx2), await count(mods, nx));
    expect(await count(objs, nx2), await count(objs, nx));
    expect(await count(pages, nx2), await count(pages, nx));
    expect(await count(links, nx2), await count(links, nx));

    final bare = await BundleService.capture(db, made.folderId!);
    expect((bare['modules'] as List).every((m) => (m as Map)['objects'] == null), isTrue, reason: 'structure only');
  });

  test("shape: the preview's counts are the desktop's (Fantasy: 3 folders · 8 modules · 1 link · 4 samples)", () async {
    final b = (await BundleService.loadBundles('en')).firstWhere((b) => b['id'] == 'fantasy');
    final sh = BundleService.shape({...(b['spec'] as Map), 'name': b['name']});
    expect((sh.folders, sh.mods.length, sh.links.length, sh.samples), (3, 8, 1, 4), reason: 'EXE bundleShape on the same spec');
    expect(sh.rows.first.kind, isNull, reason: 'the project folder first');
    expect(sh.rows.where((r) => r.kind != null).length, 8);
    final borrow = BundleService.shape({
      'modules': [
        {'ref': 'a', 'kind': 'manager', 'page': [{'component': 'x', 'borrow': 'b'}, {'type': 'columns', 'children': [[{'borrow': 'b'}], [{'borrow': 'zz'}]]}]},
        {'ref': 'b', 'kind': 'locator'},
      ],
    });
    expect([for (final l in borrow.links) (l.from, l.to, l.borrow)], [('a', 'b', true)], reason: 'once, and never to a ref the spec lacks');
  });

  test('a borrow of a module outside the folder is left out; one inside stays bound', () async {
    final nx = await db.insert('nexus', {'name': 'C'});
    final made = await BundleService.create(db, nx, null, await ttrpg());
    final outside = await db.insert('module', {'nexus_ref': nx, 'name': 'Elsewhere', 'kind': 'locator'});
    final inside = made.moduleIds.first;
    final host = made.moduleIds.last;
    for (final (i, src) in [outside, inside].indexed) {
      await db.insert('page_block', {
        'module_ref': host, 'block_type': 'component', 'component': 'core.related', 'source_key': 'module_$src', 'block_order': 100 + i,
      });
    }
    final spec = await BundleService.capture(db, made.folderId!);
    final page = ((spec['modules'] as List).firstWhere((m) => (m as Map)['ref'] == 'm$host') as Map)['page'] as List;
    final borrows = [for (final b in page) if ((b as Map)['borrow'] != null) b['borrow']];
    expect(borrows, contains('m$inside'));
    expect(borrows, isNot(contains('m$outside')));
  });

  test('saveMine / listMine: the same name replaces', () async {
    final nx = await db.insert('nexus', {'name': 'D'});
    final made = await BundleService.create(db, nx, null, await ttrpg());
    expect(await BundleService.saveMine(db, nx, made.folderId!, 'Campaign'), greaterThan(3));
    await BundleService.saveMine(db, nx, made.folderId!, 'Campaign', samples: true);
    final mine = await BundleService.listMine(db, nx);
    expect(mine.map((b) => b['name']), ['Campaign']);
    expect(mine.single['id'], startsWith('u:'));
    expect(BundleService.hasSamples(mine.single['spec'] as Map), isTrue);
    await expectLater(BundleService.saveMine(db, nx, made.moduleIds.first, 'Nope'), throwsArgumentError, reason: 'only a folder');
  });

  test('adjust: a module left out takes its relation targets, selections, borrows and the home along', () {
    final spec = <String, dynamic>{
      'name': 'X',
      'folders': [
        {'ref': 'root', 'name': 'X'},
      ],
      'home': 'm3',
      'modules': [
        {'ref': 'm1', 'kind': 'classifier', 'name': 'People', 'fields': [
          {'key': 'home', 'name': 'Home', 'type': 'relation', 'relTo': 'm2'},
          {'key': 'age', 'name': 'Age', 'type': 'number'},
        ], 'objects': [{'ref': 'o1', 'sample': true, 'name': 'Ann'}]},
        {'ref': 'm2', 'kind': 'classifier', 'name': 'Places'},
        {'ref': 'm3', 'kind': 'manager', 'name': 'Overview', 'selects': ['m1', 'm2', 'root'], 'page': [
          {'component': 'classifier.roster', 'borrow': 'm2'},
          {'component': 'classifier.roster', 'borrow': 'm1'},
          {'type': 'columns', 'children': [
            [{'component': 'core.related', 'borrow': 'm2'}],
            [{'type': 'text'}],
          ]},
        ]},
        {'ref': 'm4', 'kind': 'wanderer', 'name': 'Road', 'uses': ['m2']},
      ],
    };
    final out = BundleService.adjust(spec, name: 'Mine', keep: {0, 2, 3}, names: {0: 'Folk'}, fieldNames: {'0:1': ''}, includeSamples: false);
    final ms = (out['modules'] as List).cast<Map>();
    expect(out['name'], 'Mine');
    expect(ms.map((m) => m['name']), ['Folk', 'Overview', 'Road']);
    expect(ms[0]['fields'], [
      {'key': 'home', 'name': 'Home', 'type': 'relation'},
    ], reason: 'relTo to a module left out goes; a blank field name drops the field');
    expect(ms[1]['selects'], ['m1', 'root']);
    expect([for (final b in ms[1]['page'] as List) (b as Map)['borrow']], ['m1', null], reason: 'the borrow of m2 goes, inside columns too');
    expect((((ms[1]['page'] as List).last as Map)['children'] as List).first, isEmpty);
    expect(ms[2]['uses'], isEmpty);
    expect(out['home'], 'm3');
    expect(out['includeSamples'], false);
    expect(BundleService.adjust(spec, name: 'Y', keep: {0})['home'], isNull, reason: 'the home was left out');
  });

  testWidgets("a bundle's home lists what its Manager selects (its filter, not its children)", (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final home = (await tester.runAsync(() async {
      final nx = await db.insert('nexus', {'name': 'E'});
      return (await BundleService.create(db, nx, null, await ttrpg())).homeId!;
    }))!;
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: ModulePage(moduleId: home))),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.textContaining('Nothing selected'), findsNothing);
    expect(find.text('NPCs'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
