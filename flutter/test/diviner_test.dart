import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/diviner_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';

/// Diviner (V5.md §11.5): the port of EXE db/diviner.js, rolled with a
/// fixed sequence so every result is known.
void main() {
  sqfliteFfiInit();

  /// Returns the queued faces in order, then 1s.
  DiceRng seq(List<int> faces) {
    var i = 0;
    return (n) => i < faces.length ? faces[i++].clamp(1, n) : 1;
  }

  test('dice parse and print like the desktop', () {
    expect(Dice.parse('2d6+1').toString(), '2d6+1');
    expect(Dice.parse(' d% ').toString(), '1d100');
    expect(Dice.parse('3D8 - 2').toString(), '3d8-2');
    expect(Dice.parse('0d6'), isNull);
    expect(Dice.parse('1d1'), isNull);
    expect(Dice.parse('101d6'), isNull);
    expect(Dice.parse('fish'), isNull);
    expect(rollDice('2d6-1', seq([3, 5]))!.text, '2d6-1 = 7 (3+5-1)');
    expect(rollDice('1d20', seq([12]))!.text, '1d20 = 12');
  });

  group('tables', () {
    late Database db;
    late DivinerDao dao;
    late int mod;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON');
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      dao = DivinerDao(db);
      final nx = await db.insert('nexus', {'name': 'W'});
      mod = await ModuleDao(db).createModule(nexusRef: nx, name: 'Tables', kind: ModuleKind.diviner);
    });
    tearDown(() => db.close());

    test('a dice table picks by range; new entries continue the ranges', () async {
      final t = await dao.createTable(mod, 'Weather', dice: '1d4');
      final a = (await dao.createEntry(t, text: 'Sun'))!;
      final b = (await dao.createEntry(t, text: 'Rain'))!;
      await dao.updateEntry(b, hi: 4);
      final es = await dao.entries(t);
      expect([for (final e in es) (e['range_lo'], e['range_hi'])], [(1, 1), (2, 4)]);
      expect((await dao.roll(t, seq([1]))).text, 'Sun');
      final r = await dao.roll(t, seq([3]));
      expect((r.text, r.entryId, r.dice), ('Rain', b, '1d4 = 3'));
      expect(a, isNot(b));
      expect((await dao.rolls(t)).length, 2);
    });

    test('bad dice are refused', () async {
      expect(() => dao.createTable(mod, 'X', dice: 'lots'), throwsFormatException);
    });

    test('weighted pick, nesting, join, and a cycle stops', () async {
      final first = await dao.createTable(mod, 'First');
      await dao.createEntry(first, text: 'Ar');
      await dao.createEntry(first, text: 'Bel');
      final second = await dao.createTable(mod, 'Second');
      await dao.createEntry(second, text: 'wen');
      final name = await dao.createTable(mod, 'Name', mode: 'join');
      await dao.createEntry(name, linkerKey: 'divt_$first');
      await dao.createEntry(name, linkerKey: 'divt_$second');
      expect((await dao.roll(name, seq([2, 1]))).text, 'Belwen');

      final loop = await dao.createTable(mod, 'Loop');
      await dao.createEntry(loop, text: 'again', linkerKey: 'divt_$loop');
      final r = await dao.roll(loop, seq([1, 1]));
      expect((r.text, r.cycle), ('again ⟲', true));
      expect(await dao.wouldCycle(first, name), isTrue);
      expect(await dao.wouldCycle(name, second), isFalse);
    });

    test('history keeps the last 200', () async {
      final t = await dao.createTable(mod, 'Coin');
      await dao.createEntry(t, text: 'H');
      for (var i = 0; i < 205; i++) {
        await dao.roll(t, seq([1]));
      }
      expect((await dao.rolls(t, limit: 1000)).length, 200);
    });
  });
}
