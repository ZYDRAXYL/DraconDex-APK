import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/bundle_service.dart';
import 'package:dracondex/data/services/page_template_service.dart';
import 'package:dracondex/features/page/component_registry.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';

/// The page catalog on the phone (Procress 14 part 3, APP docs/TEMPLATES.md
/// §2–§4): every component the vendored SDB catalog marks as shipped is
/// drawn here, every template lays out with nothing "not in this app yet",
/// Use/Undo and capture round-trip, and a v2 bundle builds whole.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final catalog = jsonDecode(File('assets/templates/pages.json').readAsStringSync()) as Map<String, dynamic>;
  // SDB marks these as not shipped anywhere yet; a template naming one
  // draws the quiet placeholder on the desktop too.
  final planned = {for (final c in catalog['components'] as List) if (c['since'] == 'planned') c['id'] as String};
  var vaults = 0;

  Future<(Database, int)> vault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return (db, await db.insert('nexus', {'name': 'World ${vaults++}'}));
  }

  test('every component the catalog ships is registered, and nothing unlisted is', () {
    final listed = {for (final c in catalog['components'] as List) c['id'] as String: c['since'] as String?};
    final shipped = listed.entries.where((e) => e.value == 'exe').map((e) => e.key).toSet();
    expect(shipped.difference(components.keys.toSet()), isEmpty, reason: 'shipped on the desktop, missing here');
    expect(components.keys.toSet().difference(listed.keys.toSet()), isEmpty, reason: 'registered but not in the SDB catalog');
  });

  test('every block a template names is a component this app draws', () {
    final missing = <String>{};
    void walk(List blocks) {
      for (final b in blocks) {
        final m = b as Map;
        if (m['component'] != null && !components.containsKey(m['component'])) missing.add('${m['component']}');
        for (final col in (m['children'] as List?) ?? const []) {
          walk(col as List);
        }
      }
    }

    for (final t in catalog['templates'] as List) {
      walk((t['page'] as List?) ?? const []);
      walk((t['itemPage'] as List?) ?? const []);
    }
    expect(missing.difference(planned), isEmpty);
  });

  test('templates: names resolve, a ★ per kind, a Classifier ★ by catType', () async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    final th = await PageTemplateService.templates('th', kind: 'author');
    expect(th.first.isDefault, isTrue);
    expect(th.first.name, isNot(startsWith('tpl')));
    expect((await PageTemplateService.defaultFor('classifier', 'en', catType: 'character'))!.id, 'classifier.characterWiki');
    expect((await PageTemplateService.defaultFor('author', 'en'))!.id, 'author.manuscript');
  });

  test('apply replaces the page, adds preset fields once, Undo puts it back; capture keeps containers', () async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    final (db, nx) = await vault();
    addTearDown(db.close);
    final m = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    await db.insert('page_block', {'module_ref': m, 'block_type': 'text', 'content': 'mine', 'block_order': 0});
    final tpl = (await PageTemplateService.templates('en', kind: 'classifier')).firstWhere((t) => t.page.any((b) => (b as Map)['type'] == 'columns'));
    final r = await PageTemplateService.apply(db, m, tpl);
    final after = await db.rawQuery('SELECT block_type, component, parent_id, config FROM page_block WHERE module_ref=? AND item_key IS NULL', [m]);
    expect(after.any((b) => b['block_type'] == 'columns'), isTrue);
    expect(after.where((b) => b['parent_id'] != null), isNotEmpty, reason: 'columns keep their children');
    expect(after.any((b) => b['content'] == 'mine'), isFalse);
    if (tpl.preset != null) expect(r.fields, greaterThan(0));
    final again = await PageTemplateService.apply(db, m, tpl);
    expect(again.fields, 0, reason: 'never onto a Classifier the user already shaped');

    final captured = await PageTemplateService.capturePage(db, m, null);
    final cols = captured.firstWhere((b) => b['type'] == 'columns');
    expect((cols['children'] as List).length, greaterThanOrEqualTo(2));
    expect((cols['config'] as Map?)?.containsKey('n') ?? false, isFalse);

    await PageTemplateService.restore(db, m, r.old);
    final back = await db.rawQuery('SELECT content FROM page_block WHERE module_ref=? AND item_key IS NULL', [m]);
    expect(back.map((b) => b['content']), ['mine']);
  });

  testWidgets('every template draws on a phone with nothing left out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync()));
    final templates = (await tester.runAsync(() => PageTemplateService.templates('en')))!;
    for (final tpl in templates) {
      final (db, mod) = (await tester.runAsync(() async {
        final (db, nx) = await vault();
        final m = await ModuleDao(db).createModule(nexusRef: nx, name: tpl.id, kind: ModuleKind.fromId(tpl.kind));
        await PageTemplateService.apply(db, m, tpl);
        return (db, m);
      }))!;
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: ModulePage(moduleId: mod))),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      final gaps = [
        for (final e in find.textContaining('not in this app yet').evaluate())
          ((e.widget as Text).data ?? '').split(' · ').first
      ];
      expect(gaps.toSet().difference(planned), isEmpty, reason: tpl.id);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    }
  });

  test('a v2 bundle: folders, field keys, template pages, samples out, home', () async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    final (db, nx) = await vault();
    addTearDown(db.close);
    final bundles = await BundleService.loadBundles('en');
    final ttrpg = bundles.firstWhere((b) => b['id'] == 'ttrpg');
    final spec = <String, dynamic>{...(ttrpg['spec'] as Map<String, dynamic>), 'name': ttrpg['name']};
    final r = await BundleService.create(db, nx, null, spec);
    expect(r.homeId, isNotNull, reason: 'the ttrpg bundle names its home');
    final folders = await db.rawQuery("SELECT id FROM module WHERE nexus_ref=? AND kind='collector'", [nx]);
    expect(folders.length, (spec['folders'] as List).length, reason: 'the root is the project folder; the rest nest in it');
    // a module's page came from its template, not the default layout
    final withPage = (spec['modules'] as List).firstWhere((m) => m['page'] is String);
    final mid = (await db.rawQuery('SELECT id FROM module WHERE nexus_ref=? AND name=?', [nx, withPage['name']])).first['id'];
    final comps = [for (final b in await db.rawQuery('SELECT component FROM page_block WHERE module_ref=? AND item_key IS NULL', [mid])) b['component']];
    final tpl = await PageTemplateService.byId(withPage['page'] as String);
    expect(comps, containsAll([for (final b in tpl!.page) if ((b as Map)['component'] != null) b['component']]));
    // field keys ride in the options
    final keyed = await db.rawQuery("SELECT options FROM classifier_template WHERE options LIKE '%\"key\":%'");
    expect(keyed, isNotEmpty);

    // the same bundle without its samples
    final (db2, nx2) = await vault();
    addTearDown(db2.close);
    // (in-memory vaults share one sqflite instance here, so count by nexus)
    Future<int> objects(Database d, int n) async =>
        (await d.rawQuery('SELECT COUNT(*) AS n FROM classifier_object o JOIN module m ON m.id=o.module_ref WHERE m.nexus_ref=?', [n])).first['n'] as int;
    final withSamples = await objects(db, nx);
    await BundleService.create(db2, nx2, null, {...spec, 'includeSamples': false});
    final without = await objects(db2, nx2);
    expect(without, lessThan(withSamples));
  });
}
