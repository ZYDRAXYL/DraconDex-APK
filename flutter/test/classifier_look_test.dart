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
import 'package:dracondex/providers/db_providers.dart';

/// Procress 29 part 7: a Classifier element's name renames in place, and its
/// dot opens the icon & colour chooser — a pick saves only its own half.
void main() {
  sqfliteFfiInit();

  testWidgets('table: one tap renames in place; the dot sets the icon, then the colour, each alone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late Database db;
    late int mod, ana;
    await tester.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      final nx = await db.insert('nexus', {'name': 'World'});
      mod = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
      ana = await ClassifierDao(db).createItem(moduleRef: mod, name: 'Ana');
      await db.insert('use_color', {'color_code': '#123456'});
      await db.insert('module_ui', {'module_ref': mod, 'ui_key': 'activeView', 'ui_value': 'table'});
    });
    addTearDown(() => tester.runAsync(db.close));
    await tester.binding.setSurfaceSize(const Size(1000, 800));
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
    Future<Map<String, Object?>> row() async => (await tester.runAsync(() => db.query('classifier_object', where: 'id=?', whereArgs: [ana])))!.first;
    await settle();

    await tester.tap(find.byKey(ValueKey('cls-name-$ana')));
    await tester.pump();
    await tester.enterText(find.byKey(ValueKey('cls-name-edit-$ana')), 'Anabel');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    expect((await row())['name'], 'Anabel');

    await tester.tap(find.byKey(ValueKey('cls-look-$ana')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('ipk-svg:star')));
    await settle();
    expect((await row())['icon'], 'svg:star');
    expect((await row())['color'], isNull);
    final colorKey = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('ipk-color-') && (w.key as ValueKey).value != 'ipk-color-custom');
    await tester.tap(colorKey.first);
    await settle();
    expect((await row())['color'], isNotNull);
    expect((await row())['icon'], 'svg:star', reason: 'a colour pick keeps the icon');
    await tester.pumpWidget(const SizedBox());
  });
}
