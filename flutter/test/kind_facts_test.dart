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
import 'package:dracondex/data/services/page_template_service.dart';
import 'package:dracondex/features/page/kind_components.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';

/// The last two page components (Procress 14 part 4, APP docs/TEMPLATES.md
/// §2.2) read the same way as on the desktop — the cases are EXE
/// test/kind-facts.test.mjs's.
void main() {
  test('facts: key: value lines, markdown or the editor HTML', () {
    const md = '# Tarven\nFounded: year −300\n- **Ruler**: the Seven Towers\n* Language : Tarvin\n\nSome prose, no colon.';
    expect(factsOf(md), [('Founded', 'year −300'), ('Ruler', 'the Seven Towers'), ('Language', 'Tarvin')]);
    expect(factsOf('<p>ก่อตั้ง: ปีที่ −300</p><p>Trade &amp; law: open</p>'), [('ก่อตั้ง', 'ปีที่ −300'), ('Trade & law', 'open')]);
  });

  test('facts: links, times, tasks, headings and code are not facts', () {
    const md = 'See https://example.com\nhttps: //x\nAt 10:30 sharp\n- [ ] Task: not a fact\n## Heading: no\n```\nkey: in code\n```\n12: 34\nReal: yes';
    expect(factsOf(md), [('Real', 'yes')]);
    expect(factsOf('a: 1\nb: 2\nc: 3', max: 2).length, 2);
    expect(factsOf(''), isEmpty);
  });

  List<Offset> sq(double x, double y, [double s = 10]) => [Offset(x, y), Offset(x + s, y), Offset(x + s, y + s), Offset(x, y + s)];
  final areas = [
    PlaceArea(1, 'North', null, sq(0, 0)),
    PlaceArea(2, 'Tarven', null, sq(10, 0)),
    PlaceArea(3, 'Far isle', null, sq(100, 100)),
    const PlaceArea(4, 'Unmapped', null, []),
  ];

  test('placecard: the area by name (any case), else the first', () {
    expect(pickArea(areas, ' tarven ')!.id, 2);
    expect(pickArea(areas, 'nowhere')!.id, 1);
    expect(pickArea(const [], 'x'), isNull);
  });

  test('placecard: the crop is the area with 40% around it; borders touch it', () {
    final (view, borders) = placeGeom(areas, areas[1]);
    expect(view, const Rect.fromLTWH(1, -9, 28, 28), reason: 'at least 20 across, centred, times 1.4');
    expect(borders.map((a) => a.name), ['North']);
    final (all, none) = placeGeom(areas, areas[3]);
    expect(all, isNotNull, reason: 'an area with no outline still shows the whole map');
    expect(none, isEmpty);
    expect(placeGeom(const [PlaceArea(9, '', null, [])], const PlaceArea(9, '', null, [])).$1, isNull);
  });

  testWidgets('both draw on their templates: a region guide and a lore page', (tester) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (db, loc, ins) = (await tester.runAsync(() async {
      await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      final nx = await db.insert('nexus', {'name': 'Facts'});
      final dao = ModuleDao(db);
      final loc = await dao.createModule(nexusRef: nx, name: 'Tarven', kind: ModuleKind.locator);
      final map = await db.insert('map', {'module_ref': loc});
      for (final (name, pts) in [('Tarven', sq(10, 0)), ('North', sq(0, 0))]) {
        final a = await db.insert('map_area', {'map_id': map, 'area_name': name});
        for (final (i, p) in pts.indexed) {
          await db.insert('map_point', {'area_id': a, 'point_order': i, 'x': p.dx, 'y': p.dy});
        }
      }
      final ins = await dao.createModule(nexusRef: nx, name: 'Lore', kind: ModuleKind.inspector);
      await db.update('module', {'description': 'Founded: year −300\nRuler: the Seven Towers'}, where: 'id=?', whereArgs: [ins]);
      for (final (m, id) in [(loc, 'locator.regionGuide'), (ins, 'inspector.lorePage')]) {
        await PageTemplateService.apply(db, m, (await PageTemplateService.byId(id))!);
      }
      return (db, loc, ins);
    }))!;
    Future<void> show(int id) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: ModulePage(moduleId: id))),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await show(loc);
    expect(find.text('Borders'), findsOneWidget, reason: 'the page is named Tarven, so Tarven is the area');
    expect(find.text('North'), findsWidgets, reason: 'a border chip (the map view lists it too)');
    expect(find.textContaining('not in this app yet'), findsNothing);
    await show(ins);
    expect(find.text('Founded'), findsOneWidget);
    expect(find.text('the Seven Towers'), findsOneWidget);
    expect(find.textContaining('not in this app yet'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
