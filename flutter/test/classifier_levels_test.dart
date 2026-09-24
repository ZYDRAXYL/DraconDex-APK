import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';

/// Level & Condition rows (EXE db/classifier.js getLevels…moveLevels).
void main() {
  sqfliteFfiInit();
  late Database db;
  late ClassifierDao cls;
  late int mod, ana, bo, power, luck;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    final nx = await db.insert('nexus', {'name': 'W'});
    mod = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    cls = ClassifierDao(db);
    ana = await cls.createItem(moduleRef: mod, name: 'Ana');
    bo = await cls.createItem(moduleRef: mod, name: 'Bo');
    power = await cls.createField(moduleRef: mod, description: 'Power');
    luck = await cls.createField(moduleRef: mod, description: 'Luck');
  });
  tearDown(() => db.close());

  test('the flags round-trip and pick the columns', () async {
    await cls.updateField(power, description: 'Power', type: 'text', levelable: true);
    await cls.updateField(luck, description: 'Luck', type: 'text', hasCondition: true, levelable: true);
    final f = {for (final x in await cls.getFields(mod)) x.id: x};
    expect(f[power]!.levelColumns, ['level_label', 'info_value']);
    expect(f[luck]!.levelColumns, ['level_label', 'condition_value', 'info_value']);
    // Leaving the flags out keeps them (a rename does not clear them).
    await cls.updateField(power, description: 'Might', type: 'text');
    expect((await cls.getFields(mod)).firstWhere((x) => x.id == power).levelable, isTrue);
  });

  test('rows are per object and per field, in order, and reorder', () async {
    final a1 = await cls.createLevel(ana, power);
    final a2 = await cls.createLevel(ana, power);
    final a3 = await cls.createLevel(ana, power);
    await cls.createLevel(ana, luck);
    await cls.createLevel(bo, power);
    await cls.updateLevelField(a1, 'level_label', 'I');
    await cls.updateLevelField(a2, 'level_label', 'II');
    await cls.updateLevelField(a3, 'info_value', 'fire');
    expect([for (final r in (await cls.getLevels(ana))[power]!) r.levelLabel], ['I', 'II', null]);
    expect((await cls.getLevels(ana))[luck]!.length, 1);

    await cls.moveLevels(ana, power, [a3, a1, a2]);
    expect([for (final r in (await cls.getLevels(ana))[power]!) r.id], [a3, a1, a2]);
    // A stale id from another row set is not renumbered into this one.
    final boRow = (await cls.getLevels(bo))[power]!.single.id;
    await cls.moveLevels(ana, power, [boRow, a3, a1, a2]);
    expect([for (final r in (await cls.getLevels(ana))[power]!) r.id], [a3, a1, a2]);

    final all = await cls.getModuleLevels(mod);
    expect(all[ana]![power]!.length, 3);
    expect(all[bo]![power]!.length, 1);

    await cls.deleteLevel(a1);
    expect((await cls.getLevels(ana))[power]!.length, 2);
    expect(() => cls.updateLevelField(a2, 'id', 'x'), throwsArgumentError);
    // Deleting the object takes its rows with it.
    await cls.deleteItem(ana);
    expect(await cls.getLevels(ana), isEmpty);
  });
}
