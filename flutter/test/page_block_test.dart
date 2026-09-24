import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/page_block_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/features/page/component_registry.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';

/// Pages made of blocks (V5.md §12, APK-V3.md §10.4): the port of EXE
/// db/page-block.js, and the responsive renderer on top of it.
void main() {
  sqfliteFfiInit();

  Future<Database> openVault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return db;
  }

  group('PageBlockDao', () {
    late Database db;
    late PageBlockDao dao;
    late int nx;
    late int mod;
    setUp(() async {
      db = await openVault();
      dao = PageBlockDao(db);
      nx = await db.insert('nexus', {'name': 'W'});
      mod = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    });
    tearDown(() async => db.close());

    test('a page is laid out once — removing every block does not bring them back', () async {
      expect(await dao.ensurePage(mod, null, defaultPageLayout(ModuleKind.classifier, 'grid')), isTrue);
      var page = await dao.list(mod);
      expect(page.blocks.map((b) => b.component), ['core.properties', 'classifier.view', 'core.related']);
      expect(page.blocks[1].preset, 'grid');
      for (final b in page.blocks) {
        await dao.delete(b.id);
      }
      expect(await dao.ensurePage(mod, null, defaultPageLayout(ModuleKind.classifier, null)), isFalse);
      page = await dao.list(mod);
      expect(page.blocks, isEmpty);
      expect(page.from, PageSource.none);
      // A collector's page is its children: no blocks at all.
      expect(defaultPageLayout(ModuleKind.collector, null), isEmpty);
    });

    test('an element page reads the shared layout until split, and reverts to it', () async {
      await dao.ensurePage(mod, '*', itemPageLayout());
      var el = await dao.list(mod, 'cobj_1');
      expect(el.from, PageSource.shared);
      expect(el.blocks.first.component, 'item.body');
      expect(await dao.split(mod, 'cobj_1'), isTrue);
      await dao.add(mod, 'cobj_1', const NewBlock(type: 'text', content: 'Only mine'));
      el = await dao.list(mod, 'cobj_1');
      expect(el.from, PageSource.own);
      expect(el.blocks.length, 4);
      expect((await dao.list(mod, '*')).blocks.length, 3, reason: 'the shared layout is untouched');
      // Properties are the element's data, not its layout: a revert keeps them.
      await dao.setProp(mod, 'cobj_1', null, 'Age', '24');
      expect(await dao.revert(mod, 'cobj_1'), isTrue);
      expect((await dao.list(mod, 'cobj_1')).from, PageSource.shared);
      expect((await dao.props(mod, 'cobj_1')).single.content, '24');
    });

    test('move stays among siblings; delete returns rows that restore exactly', () async {
      final a = await dao.add(mod, null, const NewBlock(type: 'text', content: 'a'));
      final cols = await dao.add(mod, null, const NewBlock(type: 'columns', config: {'n': 2}));
      final c1 = await dao.add(mod, null, NewBlock(type: 'text', content: 'left', parentId: cols, config: const {'col': 0}));
      final c2 = await dao.add(mod, null, NewBlock(type: 'text', content: 'right', parentId: cols, config: const {'col': 1}));
      await dao.move(a, 1); // after the columns block, among top-level blocks only
      final top = [for (final b in (await dao.list(mod)).blocks) if (b.parentId == null) b.id];
      expect(top, [cols, a]);
      await dao.move(c2, 0);
      final kids = [for (final b in (await dao.list(mod)).blocks) if (b.parentId == cols) b.id];
      expect(kids, [c2, c1]);
      final rows = await dao.delete(cols);
      expect(rows.length, 3, reason: 'the columns block and both children');
      expect((await dao.list(mod)).blocks.map((b) => b.id), [a]);
      await dao.restore(rows);
      expect((await dao.list(mod)).blocks.length, 4);
    });

    test('text blocks index their [[links]] under the page; clearItem forgets an element', () async {
      await dao.add(mod, null, const NewBlock(type: 'text', content: 'See [[Cast]].'));
      final links = await db.rawQuery('SELECT src_key, target_key FROM wiki_link');
      expect(links.single['src_key'], 'module_$mod');
      expect(links.single['target_key'], 'module_$mod');
      await dao.add(mod, 'cobj_7', const NewBlock(type: 'text', content: 'x'));
      await dao.add(mod, null, const NewBlock(component: 'classifier.view', sourceKey: 'cobj_7'));
      await dao.clearItem('cobj_7');
      expect(await db.rawQuery("SELECT 1 FROM page_block WHERE item_key='cobj_7'"), isEmpty);
      expect(await db.rawQuery("SELECT 1 FROM page_block WHERE source_key='cobj_7'"), isEmpty);
    });
  });

  group('ModulePage', () {
    Future<(Database, int)> seedPage() async {
      final db = await openVault();
      final nx = await db.insert('nexus', {'name': 'W'});
      final mod = await ModuleDao(db).createModule(nexusRef: nx, name: 'Notes', kind: ModuleKind.drafter);
      final dao = PageBlockDao(db);
      await db.insert('module_ui', {'module_ref': mod, 'ui_key': 'pageInit', 'ui_value': '1'});
      final cols = await dao.add(mod, null, const NewBlock(type: 'columns', config: {'n': 2}));
      await dao.add(mod, null, NewBlock(type: 'text', content: 'Left side', parentId: cols, config: const {'col': 0}));
      await dao.add(mod, null, NewBlock(type: 'text', content: 'Right side', parentId: cols, config: const {'col': 1}));
      await dao.add(mod, null, const NewBlock(type: 'heading', content: 'Chapter'));
      return (db, mod);
    }

    Future<void> pumpPage(WidgetTester tester, Size size) async {
      SharedPreferences.setMockInitialValues({});
      final (db, mod) = (await tester.runAsync(seedPage))!;
      addTearDown(() => tester.runAsync(db.close));
      await tester.binding.setSurfaceSize(size);
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
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    testWidgets('a columns block stacks on a phone', (tester) async {
      await pumpPage(tester, const Size(390, 800));
      expect(find.text('Chapter'), findsOneWidget);
      final l = tester.getTopLeft(find.text('Left side'));
      final r = tester.getTopLeft(find.text('Right side'));
      expect(r.dy, greaterThan(l.dy), reason: 'stacked: right under left');
    });

    testWidgets('and sits side by side on a tablet', (tester) async {
      await pumpPage(tester, const Size(1000, 800));
      final l = tester.getTopLeft(find.text('Left side'));
      final r = tester.getTopLeft(find.text('Right side'));
      expect(r.dx, greaterThan(l.dx));
      expect(r.dy, closeTo(l.dy, 1));
    });
  });
}
