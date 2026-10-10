import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/features/page/views/classifier_views.dart';
import 'package:dracondex/providers/db_providers.dart';

/// Procress 19 F2/F3: a 3,000-element Classifier draws only the rows on
/// screen in every preset that lists them, and one edited value patches its
/// cell without re-reading the elements.
void main() {
  sqfliteFfiInit();
  const n = 3000;
  final name = RegExp(r'^E\d{4}$');

  Future<(Database, int, int, int)> seed(String preset) async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    final nx = await db.insert('nexus', {'name': 'World'});
    final m = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final hp = await ClassifierDao(db).createField(moduleRef: m, description: 'HP', attributeType: 'number');
    final b = db.batch();
    for (var i = 0; i < n; i++) {
      b.insert('classifier_object', {'module_ref': m, 'name': 'E${'$i'.padLeft(4, '0')}', 'display_order': i});
    }
    await b.commit(noResult: true);
    final first = (await db.rawQuery('SELECT MIN(id) AS id FROM classifier_object')).first['id'] as int;
    await db.insert('module_ui', {'module_ref': m, 'ui_key': 'activeView', 'ui_value': preset});
    return (db, m, hp, first);
  }

  for (final preset in ['table', 'listDetail', 'grid']) {
    testWidgets('$preset builds only what shows', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (db, m, hp, first) = (await tester.runAsync(() => seed(preset)))!;
      addTearDown(() => tester.runAsync(db.close));
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // the page's real host: one scroll view of blocks
          home: Scaffold(body: ListView(children: [ModulePage(moduleId: m)])),
        ),
      ));
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
          await tester.pump();
        }
      }

      await settle();
      expect(find.text('E0000'), findsWidgets);
      expect(find.text('E2999'), findsNothing);
      final built = find.textContaining(name).evaluate().length;
      expect(built, lessThan(80), reason: '$built of $n rows built');

      if (preset == 'table') {
        final c = ProviderScope.containerOf(tester.element(find.byType(ModulePage)));
        final items = c.read(clsItemsProvider(m)).valueOrNull;
        await tester.runAsync(() => c.read(clsValuesProvider(m).notifier).set(first, hp, '99'));
        await settle();
        expect(find.text('99'), findsOneWidget);
        expect(identical(c.read(clsItemsProvider(m)).valueOrNull, items), isTrue, reason: 'elements not re-read');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
