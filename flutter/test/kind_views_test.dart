import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/data/dao/author_dao.dart';
import 'package:dracondex/data/dao/chronicler_dao.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/designer_dao.dart';
import 'package:dracondex/data/dao/diviner_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/narrator_dao.dart';
import 'package:dracondex/data/dao/scribe_dao.dart';
import 'package:dracondex/data/dao/sketcher_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/features/page/component_registry.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';

/// Every kind's view builds in every one of its presets (APK-V3.md §6, the
/// 43 views of V5.md §12), on a phone and on a tablet, over a vault with a
/// little of each kind's data in it.
void main() {
  sqfliteFfiInit();

  const filter = '{"groups":[{"rules":[{"field":"name","op":"contains","value":"a"}]}]}';

  Future<(Database, int)> seed(ModuleKind kind, String preset) async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    final nx = await db.insert('nexus', {'name': 'World'});
    final mods = ModuleDao(db);
    final cast = await mods.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final cls = ClassifierDao(db);
    final hp = await cls.createField(moduleRef: cast, description: 'HP', attributeType: 'number');
    await cls.createField(moduleRef: cast, description: 'Double', attributeType: 'formula');
    await db.rawUpdate('UPDATE classifier_template SET options=? WHERE description=?', ['{"expr":"{HP} * 2"}', 'Double']);
    final rel = await cls.createField(moduleRef: cast, description: 'Ally', attributeType: 'relation');
    final ana = await cls.createItem(moduleRef: cast, name: 'Ana');
    final bram = await cls.createItem(moduleRef: cast, name: 'Bram');
    await cls.setValue(objectRef: ana, templateRef: hp, value: '12');
    await cls.addFieldRelation(ana, rel, 'cobj_$bram');

    final m = kind == ModuleKind.classifier ? cast : await mods.createModule(nexusRef: nx, name: 'Aview', kind: kind);
    switch (kind) {
      case ModuleKind.author:
        final a = AuthorDao(db);
        final c = await a.createChapter(moduleRef: m, name: 'Arrival');
        await a.updateChapterContent(c, 'It began with [[Ana]].');
        await a.setChapterMeta(c, synopsis: 'She arrives', status: 'draft', povKey: 'cobj_$ana');
        await a.createChapter(moduleRef: m, name: 'Departure');
      case ModuleKind.narrator:
        final n = NarratorDao(db);
        final d1 = await n.createDialogue(moduleRef: m, name: 'Gate');
        final d2 = await n.createDialogue(moduleRef: m, name: 'Hall');
        await n.addTalk(dialogueRef: d1, speaker: 'Ana', sentence: 'Open up.');
        await n.addEdge(moduleRef: m, fromRef: d1, toRef: d2, label: 'enter');
      case ModuleKind.chronicler:
        final c = ChroniclerDao(db);
        final tl = await c.ensureTimeline(m);
        await c.createEvent(timelineId: tl, startDateId: await c.ensureDate(day: 3, month: 2, years: 1020), name: 'Siege');
        await c.createEvent(timelineId: tl, startDateId: await c.ensureDate(day: 9, month: 2, years: 1021), name: 'Peace');
        await mods.createModule(nexusRef: nx, name: 'Other line', kind: ModuleKind.chronicler);
      case ModuleKind.sketcher:
        final s = SketcherDao(db);
        final p = await s.createPage(moduleRef: m, name: 'Map sketch');
        await s.addStroke(pageRef: p, color: '#38bdf8', width: 4, points: [10, 10, 200, 150, 400, 90]);
      case ModuleKind.designer:
        final d = DesignerDao(db);
        final a = await d.createNode(moduleRef: m, x: 0, y: 0, text: 'Start');
        final b = await d.createNode(moduleRef: m, x: 300, y: 40, shape: 'panel', text: 'Panel');
        await d.createNode(moduleRef: m, x: 20, y: 260, shape: 'balloon', text: 'Hi');
        await d.addEdge(moduleRef: m, fromRef: a, toRef: b, label: 'next');
        await d.renumberReadOrder(m);
      case ModuleKind.scribe:
        final s = ScribeDao(db);
        final ses = await s.createSession(moduleRef: m, name: 'Session 1');
        await s.addMessage(sessionRef: ses, message: 'Met [[Ana]] today');
      case ModuleKind.diviner:
        final d = DivinerDao(db);
        final t = await d.createTable(m, 'Weather', dice: '1d6');
        await d.createEntry(t, text: 'Rain');
        await d.roll(t, (n) => 1);
      case ModuleKind.exhibitor || ModuleKind.manager:
        await db.insert('module_ui', {'module_ref': m, 'ui_key': 'filterDef', 'ui_value': filter});
        await db.insert('entity_relation', {'nexus_ref': nx, 'from_key': 'cobj_$ana', 'to_key': 'cobj_$bram', 'label': 'knows'});
        if (kind == ModuleKind.exhibitor) {
          await db.insert('module_ui', {'module_ref': m, 'ui_key': 'seedScene', 'ui_value': '1'});
        }
      default:
        break;
    }
    if (preset.isNotEmpty) await db.insert('module_ui', {'module_ref': m, 'ui_key': 'activeView', 'ui_value': preset});
    return (db, m);
  }

  Future<void> pump(WidgetTester tester, ModuleKind kind, String preset, Size size) async {
    SharedPreferences.setMockInitialValues({});
    final (db, mod) = (await tester.runAsync(() => seed(kind, preset)))!;
    await tester.binding.setSurfaceSize(size);
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
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    await tester.binding.setSurfaceSize(null);
  }

  for (final def in components.values.where((d) => d.kind != null)) {
    final kind = def.kind!;
    if (kind == ModuleKind.collector) continue;
    for (final preset in def.presets.isEmpty ? [''] : def.presets) {
      testWidgets('${kind.id} · ${preset.isEmpty ? '(one view)' : preset}', (tester) async {
        await pump(tester, kind, preset, const Size(390, 820));
        await pump(tester, kind, preset, const Size(1000, 800));
      });
    }
  }

  testWidgets('the Narrator play-test reads a scene and follows a route', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final (db, mod) = (await tester.runAsync(() => seed(ModuleKind.narrator, 'reader')))!;
    addTearDown(() => tester.runAsync(db.close));
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: ModulePage(moduleId: mod))),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
    }

    await settle();
    await tester.tap(find.text('Play-test'));
    await settle();
    expect(find.text('Gate'), findsOneWidget);
    expect(find.textContaining('Open up.', findRichText: true), findsOneWidget);
    await tester.tap(find.text('→ enter'));
    await settle();
    expect(find.text('Hall'), findsOneWidget);
    expect(find.text('The end — no route leads on.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('there are 43 views', () {
    final n = components.values.where((d) => d.kind != null).fold<int>(0, (a, d) => a + (d.presets.isEmpty ? 1 : d.presets.length));
    expect(n, 43);
  });
}
