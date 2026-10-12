// Phone screenshots without an emulator (APP Plan.md Procress 21 part 1 and
// Procress 23): the real app — DraconDexApp, its router, a throwaway
// vault — pumped at 390×844 with the bundled fonts loaded, Android and iOS
// style, and each screen written out as a PNG.
//
// Not part of `flutter test`: the file is not named *_test.dart, so the
// default run skips it and CI is unchanged. Run it by path:
//
//   flutter test test/screenshots/shots.dart --dart-define=SHOTS=lists
//   flutter test test/screenshots/shots.dart --dart-define=SHOTS=glass
//
// PNGs land in tmp-shots/<set>/ (gitignored), or --dart-define=SHOTS_OUT=<dir>.
// Only APIs that predate Procress 21 are used, so the same file runs on an
// older checkout for the "before" set.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/app.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/router/app_router.dart';
import 'package:dracondex/data/dao/author_dao.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/hashtag_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/narrator_dao.dart';
import 'package:dracondex/data/dao/sketcher_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/trash_service.dart';
import 'package:dracondex/data/services/update_service.dart';
import 'package:dracondex/features/tools/share_inbox.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/providers/update_provider.dart';

const _set = String.fromEnvironment('SHOTS', defaultValue: 'lists');
const _outDefine = String.fromEnvironment('SHOTS_OUT');
final _out = _outDefine.isNotEmpty ? _outDefine : 'tmp-shots/$_set';
final _root = GlobalKey();

/// The bundled fonts under their own families, and NotoSans again under the
/// names the framework asks for when a theme does not say (Roboto, SF) — the
/// test engine draws an unknown family as boxes.
Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final a in f['fonts'] as List) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
  for (final alias in const ['Roboto', '.SF Pro Text', '.SF Pro Display', '.SF UI Text', '.SF UI Display', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
    final loader = FontLoader(alias)
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await loader.load();
  }
}

class _Vault {
  late Database db;
  late int nexus, cast, book, board, talk;
}

Future<_Vault> _seed() async {
  final v = _Vault();
  final dir = await Directory.systemTemp.createTemp('ddx-shots');
  v.db = await databaseFactoryFfi.openDatabase('${dir.path}/v.db');
  for (final sql in vaultCreateStatements) {
    await v.db.execute(sql);
  }
  final mods = ModuleDao(v.db);
  v.nexus = await mods.createNexus(name: 'World', memo: 'A coastal fantasy setting');
  await mods.createNexus(name: 'Archive', memo: 'Old drafts');
  await mods.createNexus(name: 'Short stories');
  final folder = await mods.createModule(nexusRef: v.nexus, name: 'Characters', kind: ModuleKind.collector);
  v.cast = await mods.createModule(nexusRef: v.nexus, parentId: folder, name: 'Cast', kind: ModuleKind.classifier);
  v.book = await mods.createModule(nexusRef: v.nexus, name: 'Book one', kind: ModuleKind.author);
  v.board = await mods.createModule(nexusRef: v.nexus, name: 'Storyboard', kind: ModuleKind.sketcher);
  v.talk = await mods.createModule(nexusRef: v.nexus, name: 'Dialogues', kind: ModuleKind.narrator);
  await mods.createModule(nexusRef: v.nexus, name: 'Timeline', kind: ModuleKind.chronicler);
  await mods.createModule(nexusRef: v.nexus, name: 'Places', kind: ModuleKind.locator);
  final cls = ClassifierDao(v.db);
  final role = await cls.createField(moduleRef: v.cast, description: 'Role', attributeType: 'text');
  final home = await cls.createField(moduleRef: v.cast, description: 'Home', attributeType: 'text');
  for (final (n, r, h) in const [
    ('Ana', 'Scout', 'Saltmere'),
    ('Bram', 'Smith', 'Hollowgate'),
    ('Corin', 'Captain', 'Saltmere'),
    ('Dela', 'Healer', 'Fenward'),
    ('Esk', 'Thief', 'Hollowgate'),
  ]) {
    final id = await cls.createItem(moduleRef: v.cast, name: n);
    await cls.setValue(objectRef: id, templateRef: role, value: r);
    await cls.setValue(objectRef: id, templateRef: home, value: h);
  }
  final author = AuthorDao(v.db);
  for (final c in const ['The harbour', 'Ash on the water', 'A borrowed ship', 'Fenward']) {
    await author.createChapter(moduleRef: v.book, name: c);
  }
  final sk = SketcherDao(v.db);
  for (final p in const ['Opening', 'The chase', 'Storm']) {
    await sk.createPage(moduleRef: v.board, name: p);
  }
  final nr = NarratorDao(v.db);
  for (final d in const ['Ana meets Bram', 'At the gate', 'The captain refuses']) {
    await nr.createDialogue(moduleRef: v.talk, name: d);
  }
  final tags = HashtagDao(v.db);
  for (final t in const ['hero', 'villain', 'draft']) {
    await tags.createHashtag(t, null);
  }
  for (final n in const ['Old notes', 'Unused map']) {
    final id = await mods.createModule(nexusRef: v.nexus, name: n, kind: ModuleKind.scribe);
    await TrashService.trashModule(v.db, v.nexus, id);
  }
  return v;
}

void main() {
  sqfliteFfiInit();
  setUpAll(() async {
    await _loadFonts();
    // a screenshot, not a test: real shadows (the test default draws them
    // as hard black outlines) and no DEBUG ribbon
    debugDisableShadows = false;
    WidgetsApp.debugAllowBannerOverride = false;
  });

  late _Vault v;

  Future<void> settle(WidgetTester t, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester t, {required String theme, required bool glass, required bool ios}) async {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({
      'theme': theme,
      'locale': 'en',
      if (glass) 'ui_style': 'glass',
      if (glass) 'glass_blur': 'on',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ShareInbox.channel, (call) async => const <Object?>[]);
    debugDefaultTargetPlatformOverride = ios ? TargetPlatform.iOS : TargetPlatform.android;
    debugDisableShadows = false;
    v = (await t.runAsync(_seed))!;
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    t.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    t.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    await t.pumpWidget(RepaintBoundary(
      key: _root,
      child: ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async => v.db),
          updateCheckProvider.overrideWith((ref) async => const UpdateCheckResult(available: false, dismissed: false, current: '0')),
          appVersionProvider.overrideWith((ref) async => '0'),
        ],
        child: const DraconDexApp(),
      ),
    ));
    await settle(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(v.db.close);
    t.view.reset();
    debugDefaultTargetPlatformOverride = null;
    debugDisableShadows = true; // the binding checks it is back at the end of each test
  }

  Future<void> go(WidgetTester t, String location) async {
    appRouter.go(location);
    await settle(t);
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 6);
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_root));
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  /// Taps the first hit-testable match, if there is one.
  Future<bool> tapIf(WidgetTester t, Finder f) async {
    final hit = f.hitTestable();
    if (hit.evaluate().isEmpty) return false;
    await t.tap(hit.first);
    await settle(t);
    return true;
  }

  Finder rowMenuOf(String row) =>
      find.descendant(of: find.widgetWithText(ListTile, row), matching: find.byTooltip('More actions'));

  if (_set == 'lists') {
    // Procress 21: every list APK has, before and after the shared list widgets
    for (final ios in const [false, true]) {
      for (final theme in const ['daylight', 'midnight']) {
        final p = '${ios ? 'ios' : 'android'}-$theme';
        testWidgets('lists $p', (t) async {
          await open(t, theme: theme, glass: false, ios: ios);
          await go(t, '/');
          await shot(t, '$p-01-nexus-list');
          await go(t, '/hub/${v.nexus}');
          await shot(t, '$p-02-module-explorer');
          await go(t, '/hub/${v.nexus}/module/${v.cast}');
          await shot(t, '$p-03-classifier');
          await go(t, '/hub/${v.nexus}/module/${v.book}');
          await shot(t, '$p-04-author');
          await go(t, '/hub/${v.nexus}/module/${v.board}');
          await shot(t, '$p-05-sketcher');
          await go(t, '/hub/${v.nexus}/module/${v.talk}');
          await shot(t, '$p-06-narrator');
          await go(t, '/search');
          final field = find.byType(TextField).hitTestable();
          if (field.evaluate().isNotEmpty) {
            await t.enterText(field.first, 'a');
            await settle(t);
          }
          await shot(t, '$p-07-search');
          await go(t, '/trash/${v.nexus}');
          await shot(t, '$p-08-trash');
          await go(t, '/problems/${v.nexus}');
          await shot(t, '$p-09-problems');
          await go(t, '/assets/${v.nexus}');
          await shot(t, '$p-10-assets');
          await go(t, '/settings');
          await shot(t, '$p-11-settings');
          await go(t, '/tags');
          await shot(t, '$p-12-tags');
          await go(t, '/colors');
          await shot(t, '$p-13-colors');
          await close(t);
        });
      }
    }
  }

  if (_set == 'glass') {
    // Procress 23: Glass on the three themes it was tuned on
    for (final ios in const [false, true]) {
      for (final theme in const ['daylight', 'midnight', 'moonlight']) {
        final p = '${ios ? 'ios' : 'android'}-$theme';
        testWidgets('glass $p', (t) async {
          await open(t, theme: theme, glass: true, ios: ios);
          await go(t, '/');
          await shot(t, '$p-01-home');
          await go(t, '/hub/${v.nexus}/module/${v.cast}');
          await shot(t, '$p-02-classifier');
          await go(t, '/hub/${v.nexus}');
          if (await tapIf(t, rowMenuOf('Book one'))) await shot(t, '$p-03-row-menu');
          if (await tapIf(t, find.text('Rename'))) await shot(t, '$p-04-dialog');
          await t.tapAt(const Offset(4, 400));
          await settle(t);
          if (find.byType(AlertDialog).evaluate().isNotEmpty) {
            await tapIf(t, find.text('Cancel'));
          }
          // from inside the page, as the app's own snack bars are
          final ctx = t.element(find.text('Places').first);
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: const Text('Moved “Old notes” to Trash'),
            action: SnackBarAction(label: 'Undo', onPressed: () {}),
          ));
          await settle(t);
          await shot(t, '$p-05-snackbar');
          await close(t);
        });
      }
    }
  }
}
