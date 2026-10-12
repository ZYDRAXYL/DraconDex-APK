import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/app.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/router/app_router.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/services/bundle_service.dart';
import 'package:dracondex/data/services/update_service.dart';
import 'package:dracondex/features/hub/new_nexus_screen.dart';
import 'package:dracondex/features/tools/share_inbox.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/providers/update_provider.dart';

/// New Nexus in two steps (APP Plan.md Procress 25 part 5, docs/UX-LAYOUT.md
/// §14.7): the templates full-screen, then the form in a sheet; Create
/// builds the Nexus, the template, App Docs, and opens the Nexus.
void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() {
    // an asset load a test left half-way is cached as a future that never
    // completes in the next test's zone
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ShareInbox.channel, (call) async => const <Object?>[]);
  });
  tearDown(() => NewNexusScreen.applySpec = (d, id, spec) => BundleService.create(d, id, null, spec));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 14; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // sqflite answers from another isolate, and each answer's continuation runs
  // in the test's fake zone — a template is hundreds of statements, so Create
  // needs as many pumps, not a fixed handful.
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 4000 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 1));
    }
    await settle(tester);
  }

  String path() => appRouter.routerDelegate.currentConfiguration.uri.path;

  Future<void> start(WidgetTester tester, {List<String> nexuses = const []}) async {
    await tester.runAsync(() async {
      // a file of its own per test: a failed test never closes its vault,
      // and `:memory:` would hand the next test the same one
      final dir = await Directory.systemTemp.createTemp('ddx-new-nexus');
      db = await databaseFactoryFfi.openDatabase('${dir.path}/v.db');
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      for (final n in nexuses) {
        await ModuleDao(db).createNexus(name: n);
      }
    });
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        updateCheckProvider.overrideWith((ref) async => const UpdateCheckResult(available: false, dismissed: false, current: '0')),
        appVersionProvider.overrideWith((ref) async => '0'),
      ],
      child: const DraconDexApp(),
    ));
    appRouter.go('/');
    await settle(tester);
    await tester.tap(find.byTooltip('New Nexus').hitTestable().first);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Future<List<Map<String, Object?>>> rows(WidgetTester tester, String sql, [List<Object?> args = const []]) async =>
      (await tester.runAsync(() => db.rawQuery(sql, args)))!;

  Finder sheet() => find.byType(BottomSheet);
  Finder createButton() => find.descendant(of: sheet(), matching: find.widgetWithText(FilledButton, 'Create Nexus'));

  testWidgets('step 1 is the templates, Blank first; a card opens the form in one sheet', (tester) async {
    await start(tester);
    expect(find.byType(NewNexusScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('nexus-tpl-blank')), findsOneWidget);
    // one scroll of shelves: Fantasy is on screen without choosing Genre
    expect(find.text('Fantasy novel').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Classic'));
    await settle(tester);
    expect(find.byKey(const ValueKey('nexus-tpl-classicDirector')).hitTestable(), findsOneWidget, reason: 'Classic jumps to its shelf');

    await tester.tap(find.byKey(const ValueKey('nexus-tpl-classicDirector')));
    await settle(tester);
    expect(sheet(), findsOneWidget);
    final name = tester.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('new-nexus-name')), matching: find.byType(TextField)));
    expect(name.controller!.text, 'New Nexus');
    expect(name.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 9), reason: 'typing replaces it');
    // the first Nexus gets App Docs by default
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('new-nexus-appdocs'))).value, isTrue);
    await finish(tester);
  });

  testWidgets('a taken name: the default skips it, typing it shows the error under the field', (tester) async {
    await start(tester, nexuses: ['New Nexus', 'World']);
    await tester.tap(find.byKey(const ValueKey('nexus-tpl-blank')));
    await settle(tester);
    final field = find.descendant(of: find.byKey(const ValueKey('new-nexus-name')), matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).controller!.text, 'New Nexus 2');
    // not the first Nexus: no App Docs unless asked
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('new-nexus-appdocs'))).value, isFalse);
    await tester.enterText(field, 'world');
    await settle(tester);
    expect(find.text('A Nexus with this name already exists'), findsOneWidget);
    expect(tester.widget<FilledButton>(createButton()).onPressed, isNull);
    await finish(tester);
  });

  testWidgets('Create: the Nexus, the template, App Docs, then the new Nexus opens', (tester) async {
    await start(tester, nexuses: ['World']);
    await tester.tap(find.text('Fantasy novel'));
    await settle(tester);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('new-nexus-name')), matching: find.byType(TextField)), 'Eldoria');
    await tester.tap(find.byKey(const ValueKey('new-nexus-appdocs')));
    await settle(tester);
    await tester.tap(createButton());
    await settleUntil(tester, () => path().startsWith('/hub/'));

    final nx = await rows(tester, "SELECT id FROM nexus WHERE name='Eldoria'");
    expect(nx, hasLength(1));
    final id = nx.first['id'] as int;
    final top = [for (final r in await rows(tester, 'SELECT name FROM module WHERE nexus_ref=? AND parent_id IS NULL ORDER BY id', [id])) r['name']];
    expect(top, ['Fantasy novel', 'Guide'], reason: 'template first, then App Docs in its own folder');
    expect(path(), '/hub/$id');
    expect(sheet(), findsNothing);
    await finish(tester);
  });

  testWidgets('a template that fails keeps the Nexus, and Retry adds it', (tester) async {
    await start(tester, nexuses: ['World']);
    NewNexusScreen.applySpec = (d, id, spec) async => throw StateError('boom');
    await tester.tap(find.text('Fantasy novel'));
    await settle(tester);
    await tester.tap(createButton());
    await settleUntil(tester, () => path().startsWith('/hub/'));

    final nx = await rows(tester, "SELECT id FROM nexus WHERE name='New Nexus'");
    expect(nx, hasLength(1), reason: 'the Nexus stays');
    final id = nx.first['id'] as int;
    expect(await rows(tester, 'SELECT id FROM module WHERE nexus_ref=?', [id]), isEmpty);
    expect(find.text('Nexus created, but the template could not be added'), findsOneWidget);

    var applied = 0;
    NewNexusScreen.applySpec = (d, id, spec) async {
      await BundleService.create(d, id, null, spec);
      applied++;
    };
    await tester.tap(find.text('Retry'));
    await settleUntil(tester, () => applied > 0);
    final top = await rows(tester, 'SELECT name FROM module WHERE nexus_ref=? AND parent_id IS NULL', [id]);
    expect([for (final r in top) r['name']], ['Fantasy novel']);
    await finish(tester);
  });

  testWidgets('Cancel makes nothing', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('nexus-tpl-blank')));
    await settle(tester);
    await tester.tap(find.descendant(of: sheet(), matching: find.text('Cancel')));
    await settle(tester);
    expect(await rows(tester, 'SELECT id FROM nexus'), isEmpty);
    expect(find.byType(NewNexusScreen), findsOneWidget);
    await finish(tester);
  });
}
