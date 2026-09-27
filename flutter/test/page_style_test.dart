import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/page_block_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/models/viewer_model.dart';
import 'package:dracondex/features/page/block_options.dart';
import 'package:dracondex/features/page/block_style.dart';
import 'package:dracondex/features/page/links.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';
import 'package:dracondex/widgets/markdown_view.dart';

/// Block style, page links, footnotes and the containers on the phone
/// (Procress 14, APP docs/TEMPLATES.md §6–§7): the desktop's stored shapes
/// read the same way here, and nothing but http(s) becomes a web link.
void main() {
  sqfliteFfiInit();

  IndexedItem item(String key, String kind, String name, int moduleId) => IndexedItem(
        key: key, itemKind: kind, name: name, moduleId: moduleId, moduleName: 'Cast', moduleKind: 'classifier', moduleParentId: null, //
      );

  group('style', () {
    test('known values only, each defaulted', () {
      final st = BlockStyle.of({
        'style': {'variant': 'hero', 'accent': 'neon', 'width': 'wide', 'hideOn': 'phone', 'header': {'show': true, 'title': 'Bio'}, 'anchor': 'Early Life!'},
      });
      expect((st.variant, st.accent, st.width, st.hideOn, st.align), ('hero', 'accent', 'wide', 'phone', 'left'));
      expect((st.headerShow, st.headerTitle, st.anchor), (true, 'Bio', 'early-life'));
      expect(BlockStyle.of(const {}).isPlain, isTrue);
    });

    test('a default removes the key; an empty header is removed', () {
      var c = styleWith(const {'preset': 'x'}, 'variant', 'card');
      expect(c['style'], {'variant': 'card'});
      c = styleWith(c, 'variant', 'plain');
      expect(c.containsKey('style'), isFalse);
      expect(c['preset'], 'x');
      c = styleHeaderWith(c, show: true, title: ' T ');
      expect((c['style'] as Map)['header'], {'show': true, 'title': 'T'});
      c = styleHeaderWith(c, show: false, title: '');
      expect(c.containsKey('style'), isFalse);
      expect(styleWith(const {}, 'variant', 'neon').containsKey('style'), isFalse);
    });

    test('hero text stays readable on every accent', () {
      double lum(Color c) {
        double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
        return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
      }

      for (final c in [0xFF38BDF8, 0xFF3B82F6, 0xFF10B981, 0xFFD97706, 0xFFE11D48, 0xFF8B5CF6, 0xFF64748B, 0xFFA5B4FC]) {
        final lightest = heroColors(Color(c)).first;
        final ratio = 1.05 / (lum(lightest) + .05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: c.toRadixString(16));
      }
    });
  });

  group('options', () {
    PageBlock block(Map<String, Object?> config) => PageBlock(id: 1, moduleId: 1, type: 'component', component: 'core.linkbar', config: config);

    test('invalid reads as the default; the older top-level key still counts', () {
      expect(optValue(block({'opts': {'bar': 'neon'}}), 'bar'), 'pills');
      expect(optValue(block({'opts': {'bar': 'tabs'}}), 'bar'), 'tabs');
      expect(optValue(block({'bar': 'buttons'}), 'bar'), 'buttons');
      final tabs = PageBlock(id: 2, moduleId: 1, type: 'component', component: 'core.tabs', config: const {'opts': {'start': 99}});
      expect(optValue(tabs, 'start'), 8);
    });

    test('an empty value removes the option', () {
      final c = configWithOpt(const {'opts': {'bar': 'tabs'}}, 'bar', null);
      expect(c.containsKey('opts'), isFalse);
    });
  });

  group('links', () {
    final index = [item('module_4', 'module', 'Cast', 4), item('cobj_7', 'object', 'Ana', 4)];

    test('typed input → a stored link; anything but http(s) refused', () {
      expect(parseLinkInput('[[Ana]]', index), 'item:cobj_7');
      expect(parseLinkInput('[[Ana]]#Early', index), 'item:cobj_7#early');
      expect(parseLinkInput('Cast', index), 'module:4');
      expect(parseLinkInput('[[Nobody]]', index), 'wiki:Nobody');
      expect(parseLinkInput('#Bio', index), 'anchor:bio');
      expect(parseLinkInput('https://example.com/a', index), 'url:https://example.com/a');
      for (final bad in ['javascript:alert(1)', 'file:///etc/passwd', 'data:text/html,x', 'intent://x', '']) {
        expect(parseLinkInput(bad, index), isNull, reason: bad);
      }
    });

    test('a wiki: link mends itself once the page exists', () {
      const l = PageLink('wiki:Bram');
      expect(resolveLink(l, index).dangling, isTrue);
      expect(resolveLink(l, null).dangling, isFalse, reason: 'no index yet is not "gone"');
      final r = resolveLink(l, [...index, item('cobj_9', 'object', 'Bram', 4)]);
      expect((r.kind, r.key, r.dangling), (LinkKind.item, 'cobj_9', false));
    });

    test('labels and stored shapes', () {
      expect(linkLabel(const PageLink('url:https://www.example.com/x'), resolveLink(const PageLink('url:https://www.example.com/x'), index)), 'example.com');
      expect(linkLabel(const PageLink('item:cobj_7', label: 'See [[Ana|her]]'), resolveLink(const PageLink('item:cobj_7'), index)), 'See her');
      expect(linksFrom([{'to': 'module:4'}, {'to': 'url:javascript:alert(1)'}, {'to': 'ftp://x'}, 'x', null]).map((l) => l.to), ['module:4']);
      expect(resolveLink(const PageLink('url:javascript:alert(1)'), index).kind, LinkKind.bad);
    });
  });

  test('footnotes are numbered by first reference across the page; code is skipped', () {
    final f = Footnotes.of(['A[^b] and [^a].\n\n[^a]: first', '```\n[^zz]\n```\nB[^a][^c]\n[^b]: second']);
    expect(f.order, ['b', 'a', 'c']);
    expect((f.number('a'), f.number('b'), f.number('zz')), ('2', '1', '?'));
    expect(f.notes, {'a': 'first', 'b': 'second'});
  });

  testWidgets('a styled page: header and fold, tabs and a toggle holding blocks, references', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final (db, mod) = (await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      final nx = await db.insert('nexus', {'name': 'World'});
      final mods = ModuleDao(db);
      final m = await mods.createModule(nexusRef: nx, name: 'Lore', kind: ModuleKind.drafter);
      final cast = await mods.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
      await ClassifierDao(db).createItem(moduleRef: cast, name: 'Ana');
      final dao = PageBlockDao(db);
      await dao.add(m, null, NewBlock(type: 'text', content: 'Old kings[^k] ruled.\n\n[^k]: The first age.', config: {
        'style': {'variant': 'tinted', 'accent': 'amber', 'header': {'show': true, 'title': 'History'}},
      }));
      await dao.add(m, null, NewBlock(type: 'text', content: 'Folded away', config: {'style': {'collapsible': 'closed', 'header': {'title': 'Secrets'}}}));
      await dao.add(m, null, NewBlock(type: 'text', content: 'Desktop only', config: {'style': {'hideOn': 'phone'}}));
      final tabs = await dao.add(m, null, NewBlock(component: 'core.tabs', config: {'opts': {'tabs': ['Early', 'Late']}}));
      await dao.add(m, null, NewBlock(type: 'text', content: 'In the early tab', parentId: tabs, config: {'col': 0}));
      await dao.add(m, null, NewBlock(type: 'text', content: 'In the late tab', parentId: tabs, config: {'col': 1}));
      final tog = await dao.add(m, null, NewBlock(component: 'core.toggle', config: {'opts': {'title': 'Spoilers'}}));
      await dao.add(m, null, NewBlock(type: 'text', content: 'Hidden twist', parentId: tog, config: {'col': 0}));
      await dao.add(m, null, NewBlock(component: 'core.linkbar', config: {
        'opts': {'links': [{'to': 'wiki:Ana'}, {'to': 'url:https://example.com'}, {'to': 'url:javascript:alert(1)'}]},
      }));
      await dao.add(m, null, NewBlock(component: 'core.references'));
      return (db, m);
    }))!;
    addTearDown(() => tester.runAsync(db.close));
    // a phone: what MediaQuery (and so hideOn) reads
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('[1]', findRichText: true), findsOneWidget);
    // with a References block on the page, the definition is listed there
    expect(find.textContaining('The first age.', findRichText: true), findsOneWidget);
    expect(find.text('Secrets'), findsOneWidget);
    expect(find.textContaining('Folded away', findRichText: true), findsNothing);
    expect(find.textContaining('Desktop only', findRichText: true), findsNothing, reason: 'hideOn: phone at 390dp');
    expect(find.textContaining('In the early tab', findRichText: true), findsOneWidget);
    expect(find.textContaining('In the late tab', findRichText: true), findsNothing);
    expect(find.textContaining('Hidden twist', findRichText: true), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('example.com', findRichText: true), findsOneWidget);
    expect(find.textContaining('javascript', findRichText: true), findsNothing, reason: 'a javascript: link is dropped, never drawn');

    await tester.tap(find.text('Secrets'));
    await tester.tap(find.text('Late'));
    await tester.tap(find.text('Spoilers'));
    await settle();
    expect(find.textContaining('Folded away', findRichText: true), findsOneWidget);
    expect(find.textContaining('In the late tab', findRichText: true), findsOneWidget);
    expect(find.textContaining('In the early tab', findRichText: true), findsNothing);
    expect(find.textContaining('Hidden twist', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
