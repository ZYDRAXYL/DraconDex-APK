import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/app.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/router/app_router.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/hashtag_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/update_service.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/features/settings/theme_picker.dart';
import 'package:dracondex/features/tools/share_inbox.dart';
import 'package:dracondex/providers/builder_view_provider.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/providers/update_provider.dart';

/// How deep customising goes on the phone (APP Plan.md Procress 24, APP
/// docs/UX-LAYOUT.md §13): every task of the desktop's depth table that APK
/// has, counted in taps from the Nexus page (`/hub/:id`, the Nest + start
/// surface) to the moment the control is on screen. The tap that changes the
/// value is not counted — choosing a theme card, a colour, a dropdown entry —
/// and neither is scrolling. A form control that shows its value and opens
/// its choices (a dropdown, a colour well) is the control.
///
/// Fails when a task takes more than 2 taps, when a step on its path is
/// gone, or when a bottom sheet opens over another sheet (more than one
/// level). The plan names `integration_test/`, but that needs a device or
/// an emulator, and neither this machine nor CI has one; the same paths run
/// here as a widget test against the real app (DraconDexApp + its router)
/// over an in-memory vault, on a 390×844 phone, so `flutter test` and CI
/// run it on every change.
///
/// Measured 2026-10-11 (before → after Procress 24 part 3):
///
/// | task                         | before | after |
/// |------------------------------|--------|-------|
/// | theme                        | 2      | 2     |
/// | language                     | 2      | 2     |
/// | UI size                      | 2      | 2     |
/// | UI style (new)               | —      | 2     |
/// | Reduce transparency (new)    | —      | 2     |
/// | Nest view (list/grid)        | 1      | 1     |
/// | rename a module              | 2      | 2     |
/// | pin a module                 | 1      | 1     |
/// | export (web page …)          | 2      | 2     |
/// | change a module's view       | 1      | 1     |
/// | add a field                  | 2      | 2     |
/// | an existing field's type     | 2      | 2     |
/// | an element's field value     | 2      | 2     |
/// | page (title) layout          | 3      | 2     |
/// | block look                   | 3      | 2     |
/// | this Nexus's name            | 3      | 2     |
/// | tag colour                   | 3      | 2     |
///
/// And one path that starts on the home screen, not the Nexus page, with a
/// limit of 3 (Procress 25, UX-LAYOUT.md §14.6): a Nexus from a template —
/// New → the template's card → Create Nexus (its name is already filled in).
/// Before: New → open "Start with" → pick → Save, 4 taps.
///
/// Not on APK, so not here: module icon/colour, a Nexus's colour and Locate
/// folder, workspace style, rail buttons, startup, packages, per-area font
/// size, custom themes.
void main() {
  sqfliteFfiInit();

  late Database db;
  late int nexus;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ShareInbox.channel, (call) async => const <Object?>[]);
  });

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      final mods = ModuleDao(db);
      nexus = await mods.createNexus(name: 'World');
      final cast = await mods.createModule(nexusRef: nexus, name: 'Cast', kind: ModuleKind.classifier);
      final cls = ClassifierDao(db);
      final role = await cls.createField(moduleRef: cast, description: 'Role', attributeType: 'text');
      final ana = await cls.createItem(moduleRef: cast, name: 'Ana');
      await cls.setValue(objectRef: ana, templateRef: role, value: 'Scout');
      await HashtagDao(db).createHashtag('hero', null);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openNexusPage(WidgetTester tester, {String? at}) async {
    await seed(tester);
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
    appRouter.go(at ?? '/hub/$nexus');
    await settle(tester);
    expect(find.text('World'), findsWidgets, reason: at == null ? 'on the Nexus page' : 'on the home screen');
  }

  // ── where to tap ────────────────────────────────────────────────────────
  Finder text(String s) => find.text(s).hitTestable();
  Finder tip(String s) => find.byTooltip(s).hitTestable();
  Finder rowMenuOf(String row) =>
      find.descendant(of: find.widgetWithText(ListTile, row), matching: find.byTooltip('More actions')).hitTestable();
  Finder pageMenu() => find.descendant(of: find.byType(AppBar), matching: find.byTooltip('More actions')).hitTestable();

  /// One task: the taps from the Nexus page, then what must be on screen.
  Future<void> depth(
    WidgetTester tester, {
    required List<Finder Function()> path,
    required Finder Function() control,
    bool scroll = false,
  }) async {
    await openNexusPage(tester);
    for (final (i, step) in path.indexed) {
      final target = step();
      expect(target, findsWidgets, reason: 'step ${i + 1} of the path is gone');
      await tester.tap(target.first);
      await settle(tester);
      expect(find.byType(BottomSheet).evaluate().length, lessThanOrEqualTo(1), reason: 'a sheet over a sheet');
    }
    if (scroll) {
      await tester.scrollUntilVisible(control(), 300, scrollable: find.byType(Scrollable).hitTestable().first);
      await settle(tester);
    }
    expect(control(), findsWidgets, reason: 'the control is not on screen after ${path.length} taps');
    expect(path.length, lessThanOrEqualTo(2), reason: 'deeper than 2 taps');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  final settings = [() => text('More'), () => text('Settings')];
  Finder Function() inDialog(Finder f) => () => find.descendant(of: find.byType(AlertDialog), matching: f);

  testWidgets('theme', (t) => depth(t, path: settings, control: () => find.byType(ThemePickerSection)));
  testWidgets('language', (t) => depth(t, path: settings, control: () => find.text('Language'), scroll: true));
  testWidgets('UI size', (t) => depth(t, path: settings, control: () => find.text('UI Scale')));
  testWidgets('UI style', (t) => depth(t, path: settings, control: () => find.byKey(const ValueKey('ui-style'))));
  testWidgets('Reduce transparency',
      (t) => depth(t, path: settings, control: () => find.byKey(const ValueKey('reduce-transparency')), scroll: true));

  testWidgets('Nest view', (t) => depth(t, path: [() => tip('View mode')], control: () => find.byType(PopupMenuItem<BuilderViewMode>)));
  testWidgets('rename a module',
      (t) => depth(t, path: [() => rowMenuOf('Cast'), () => text('Rename')], control: inDialog(find.byType(TextField))));
  testWidgets('pin a module', (t) => depth(t, path: [() => rowMenuOf('Cast')], control: () => text('Pin')));
  testWidgets('export', (t) => depth(t, path: [() => rowMenuOf('Cast'), () => text('Export…')], control: () => find.text('HTML')));

  Finder openCast() => text('Cast');
  testWidgets("change a module's view", (t) => depth(t, path: [openCast], control: () => find.byType(PresetChips)));
  testWidgets('add a field',
      (t) => depth(t, path: [openCast, () => tip('New field')], control: inDialog(find.text('Field type'))));
  testWidgets("an existing field's type",
      (t) => depth(t, path: [openCast, () => text('Role')], control: inDialog(find.text('Field type'))));
  testWidgets("an element's field value",
      (t) => depth(t, path: [openCast, () => text('Scout')],
          control: () => find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField))));

  testWidgets('page layout',
      (t) => depth(t, path: [openCast, pageMenu], control: () => find.byKey(const ValueKey('page-title-align'))));
  testWidgets('block look',
      (t) => depth(t, path: [openCast, () => text('Edit page')], control: () => find.byKey(const ValueKey('block-look'))));
  testWidgets("this Nexus's name",
      (t) => depth(t, path: [pageMenu, () => text('Rename')], control: inDialog(find.text('Rename Nexus'))));
  testWidgets('tag colour',
      (t) => depth(t, path: [() => text('More'), () => text('Tags')], control: () => find.byKey(const ValueKey('tag-color'))));

  testWidgets('a Nexus from a template (from home, ≤ 3)', (t) async {
    await openNexusPage(t, at: '/');
    final path = [
      () => tip('New Nexus'),
      () => text('Fantasy novel'),
      () => find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(FilledButton, 'Create Nexus')).hitTestable(),
    ];
    for (final (i, step) in path.indexed) {
      final target = step();
      expect(target, findsWidgets, reason: 'step ${i + 1} of the path is gone');
      await t.tap(target.first);
      await settle(t);
      expect(find.byType(BottomSheet).evaluate().length, lessThanOrEqualTo(1), reason: 'a sheet over a sheet');
    }
    // the template is hundreds of statements, each answered on another isolate
    for (var i = 0; i < 4000 && !appRouter.routerDelegate.currentConfiguration.uri.path.startsWith('/hub/'); i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump(const Duration(milliseconds: 1));
    }
    await settle(t);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, isNot('/hub/$nexus'));
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, startsWith('/hub/'), reason: 'the new Nexus is open');
    expect(path.length, lessThanOrEqualTo(3), reason: 'deeper than 3 taps');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });
}
