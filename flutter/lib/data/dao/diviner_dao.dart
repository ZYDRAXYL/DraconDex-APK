import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';
import '../services/wiki_service.dart';

/// Diviner — random tables and dice (V5.md §11.5), the port of EXE
/// db/diviner.js. A module holds tables; a table holds entries and a roll
/// history.
///
///   dice   '1d20', '2d6+1', 'd%' — an entry is chosen by range_lo..hi;
///          NULL = weighted: each entry's weight is its share
///   mode   'pick' = one entry · 'join' = every entry in order, joined (the
///          name / word generator)
///
/// An entry whose linker_key is `divt_<id>` rolls that table in its place. A
/// chain deeper than [maxDepth], or one that comes back to a table already
/// on the path, stops with a marker instead of looping.
class Dice {
  final int n;
  final int sides;
  final int mod;
  const Dice(this.n, this.sides, this.mod);

  static final _re = RegExp(r'^\s*(\d*)\s*d\s*(\d+|%)\s*(?:([+-])\s*(\d+))?\s*$', caseSensitive: false);

  /// '2d6+1' → Dice(2, 6, 1); null for anything else. Bounds keep a typo
  /// from asking for a million dice.
  static Dice? parse(String? s) {
    final m = _re.firstMatch(s ?? '');
    if (m == null) return null;
    final n = m[1]!.isEmpty ? 1 : int.parse(m[1]!);
    final sides = m[2] == '%' ? 100 : int.parse(m[2]!);
    final mod = m[3] == null ? 0 : (m[3] == '-' ? -1 : 1) * int.parse(m[4]!);
    if (n < 1 || n > 100 || sides < 2 || sides > 1000) return null;
    return Dice(n, sides, mod);
  }

  @override
  String toString() => '${n}d$sides${mod == 0 ? '' : (mod > 0 ? '+$mod' : '$mod')}';

  int get lo => n + mod;
  int get hi => n * sides + mod;
}

/// `rng(n)` returns 1..n. The default is [Random.secure] — a DM's d20
/// should not come from a predictable source.
typedef DiceRng = int Function(int n);

final Random _secure = Random.secure();
int _secureRng(int n) => _secure.nextInt(n) + 1;

class DiceRoll {
  final int total;
  final List<int> faces;
  final String text;
  const DiceRoll(this.total, this.faces, this.text);
}

DiceRoll? rollDice(String expr, [DiceRng? rng]) {
  final d = Dice.parse(expr);
  if (d == null) return null;
  final r = rng ?? _secureRng;
  final faces = [for (var i = 0; i < d.n; i++) r(d.sides)];
  final total = faces.fold(0, (a, b) => a + b) + d.mod;
  final parts = [...faces.map((f) => '$f'), if (d.mod != 0) '${d.mod}'];
  final detail = d.n > 1 || d.mod != 0 ? ' (${parts.join('+').replaceAll('+-', '-')})' : '';
  return DiceRoll(total, faces, '$d = $total$detail');
}

class DivinerResult {
  final String text;
  final String? dice;
  final int? entryId;
  final bool cycle;
  final bool deep;
  const DivinerResult(this.text, {this.dice, this.entryId, this.cycle = false, this.deep = false});
}

class DivinerDao {
  static const maxDepth = 8;
  static const modes = ['pick', 'join'];

  final Database db;
  DivinerDao(this.db);

  Future<List<Map<String, Object?>>> tables(int moduleRef) => db.rawQuery('''
    SELECT t.*, (SELECT COUNT(*) FROM diviner_entry e WHERE e.table_ref=t.id) AS entry_count
    FROM diviner_table t WHERE t.module_ref=? ORDER BY t.display_order, t.id''', [moduleRef]);

  Future<List<Map<String, Object?>>> entries(int tableRef) =>
      db.rawQuery('SELECT * FROM diviner_entry WHERE table_ref=? ORDER BY display_order, id', [tableRef]);

  Future<List<Map<String, Object?>>> rolls(int tableRef, {int limit = 30}) =>
      db.rawQuery('SELECT * FROM diviner_roll WHERE table_ref=? ORDER BY id DESC LIMIT ?', [tableRef, limit]);

  /// Every table in the Nexus — what an entry can roll on.
  Future<List<Map<String, Object?>>> tablesInNexus(int nexusId) => db.rawQuery('''
    SELECT t.id, t.name, t.module_ref, m.name AS module_name FROM diviner_table t
    JOIN module m ON t.module_ref=m.id WHERE m.nexus_ref=? ORDER BY m.name, t.display_order, t.id''', [nexusId]);

  /// null = no dice (weighted); throws [FormatException] on bad dice.
  static String? cleanDice(String? dice) {
    final s = (dice ?? '').trim();
    if (s.isEmpty) return null;
    final d = Dice.parse(s);
    if (d == null) throw const FormatException('bad_dice');
    return '$d';
  }

  Future<int> createTable(int moduleRef, String name, {String? dice, String mode = 'pick'}) async {
    final dc = cleanDice(dice);
    final o = await db.rawQuery('SELECT COALESCE(MAX(display_order),-1)+1 AS o FROM diviner_table WHERE module_ref=?', [moduleRef]);
    final id = await db.insert('diviner_table', {
      'module_ref': moduleRef,
      'name': name,
      'dice': dc,
      'mode': modes.contains(mode) ? mode : 'pick',
      'display_order': o.first['o'],
    });
    await WikiService.resolveDangling(db, name, await WikiService.nexusOfModule(db, moduleRef));
    return id;
  }

  Future<void> updateTable(int id, String name, String? dice, String mode) async {
    final dc = cleanDice(dice);
    final cur = await db.rawQuery(
        'SELECT t.name, m.nexus_ref FROM diviner_table t JOIN module m ON t.module_ref=m.id WHERE t.id=?', [id]);
    if (cur.isEmpty) return;
    await db.rawUpdate("UPDATE diviner_table SET name=?, dice=?, mode=?, update_at=datetime('now') WHERE id=?",
        [name, dc, modes.contains(mode) ? mode : 'pick', id]);
    await WikiService.renamed(db, 'divt_$id', cur.first['name'] as String?, name, cur.first['nexus_ref'] as int?);
  }

  Future<void> deleteTable(int id) async {
    await db.rawDelete('DELETE FROM page_block WHERE item_key=?', ['divt_$id']);
    await db.delete('diviner_table', where: 'id=?', whereArgs: [id]);
    // An entry elsewhere that rolled this table now rolls nothing.
    await db.rawUpdate('UPDATE diviner_entry SET linker_key=NULL WHERE linker_key=?', ['divt_$id']);
  }

  /// A dice table's new entry continues the ranges: after 1–3, 4–4.
  Future<int?> createEntry(int tableRef, {String text = '', String? linkerKey}) async {
    final t = await db.rawQuery('SELECT dice FROM diviner_table WHERE id=?', [tableRef]);
    if (t.isEmpty) return null;
    final last = await db.rawQuery(
        'SELECT MAX(range_hi) AS hi, COALESCE(MAX(display_order),-1)+1 AS o FROM diviner_entry WHERE table_ref=?', [tableRef]);
    int? lo, hi;
    final dc = Dice.parse(t.first['dice'] as String?);
    if (dc != null) {
      lo = last.first['hi'] != null ? (last.first['hi'] as int) + 1 : dc.lo;
      hi = lo;
    }
    return db.insert('diviner_entry', {
      'table_ref': tableRef,
      'weight': 1,
      'range_lo': lo,
      'range_hi': hi,
      'entry_text': text,
      'linker_key': linkerKey,
      'display_order': last.first['o'],
    });
  }

  Future<void> updateEntry(int id, {int? weight, int? lo, int? hi, String? text, String? linkerKey, bool clearLink = false}) async {
    final cur = await db.rawQuery('SELECT * FROM diviner_entry WHERE id=?', [id]);
    if (cur.isEmpty) return;
    final c = cur.first;
    var l = lo ?? c['range_lo'] as int?, h = hi ?? c['range_hi'] as int?;
    if (l != null && h != null && h < l) (l, h) = (h, l);
    if (l != null && h == null) h = l;
    await db.rawUpdate('UPDATE diviner_entry SET weight=?, range_lo=?, range_hi=?, entry_text=?, linker_key=? WHERE id=?', [
      max(0, weight ?? c['weight'] as int? ?? 1),
      l,
      h,
      text ?? c['entry_text'],
      clearLink ? null : (linkerKey ?? c['linker_key']),
      id,
    ]);
  }

  Future<void> deleteEntry(int id) => db.delete('diviner_entry', where: 'id=?', whereArgs: [id]);

  Future<void> clearRolls(int tableRef) => db.delete('diviner_roll', where: 'table_ref=?', whereArgs: [tableRef]);

  /// Would pointing [tableId]'s entry at [targetId] close a loop?
  Future<bool> wouldCycle(int tableId, int targetId) async {
    final seen = <int>{};
    Future<bool> walk(int id) async {
      if (id == tableId) return true;
      if (!seen.add(id)) return false;
      final rows = await db.rawQuery("SELECT linker_key FROM diviner_entry WHERE table_ref=? AND linker_key LIKE 'divt%'", [id]);
      for (final r in rows) {
        final k = r['linker_key'] as String;
        final sub = RegExp(r'^divt_(\d+)$').firstMatch(k);
        if (sub != null && await walk(int.parse(sub[1]!))) return true;
      }
      return false;
    }

    return walk(targetId);
  }

  static Map<String, Object?>? _pickWeighted(List<Map<String, Object?>> es, DiceRng rng) {
    final total = es.fold<int>(0, (a, e) => a + max(0, e['weight'] as int? ?? 1));
    if (total <= 0) return null;
    var r = rng(total);
    for (final e in es) {
      r -= max(0, e['weight'] as int? ?? 1);
      if (r <= 0) return e;
    }
    return es.last;
  }

  Future<DivinerResult> resolve(int tableId, DiceRng rng, [List<int> path = const []]) async {
    if (path.contains(tableId)) return const DivinerResult('⟲', cycle: true);
    if (path.length >= maxDepth) return const DivinerResult('…', deep: true);
    final t = await db.rawQuery('SELECT id, name, dice, mode FROM diviner_table WHERE id=?', [tableId]);
    if (t.isEmpty) return const DivinerResult('');
    final es = await entries(tableId);
    final next = [...path, tableId];
    Future<DivinerResult> expand(Map<String, Object?> e) async {
      final key = e['linker_key'] as String?;
      final sub = RegExp(r'^divt_(\d+)$').firstMatch(key ?? '');
      final own = e['entry_text'] as String? ?? '';
      if (sub != null) {
        final r = await resolve(int.parse(sub[1]!), rng, next);
        return DivinerResult([own, r.text].where((s) => s.isNotEmpty).join(' '), cycle: r.cycle, deep: r.deep);
      }
      final nm = key == null ? null : await EntityKinds.nameOf(db, key);
      return DivinerResult(own.isNotEmpty ? own : (nm != null ? '[[$nm]]' : ''));
    }

    if (t.first['mode'] == 'join') {
      final parts = [for (final e in es) await expand(e)];
      return DivinerResult(parts.map((p) => p.text).join(),
          cycle: parts.any((p) => p.cycle), deep: parts.any((p) => p.deep));
    }
    Map<String, Object?>? chosen;
    String? dice;
    final expr = t.first['dice'] as String?;
    if (expr != null) {
      final r = rollDice(expr, rng);
      if (r != null) {
        dice = r.text;
        chosen = es.where((e) {
          final lo = e['range_lo'] as int?;
          if (lo == null) return false;
          final hi = e['range_hi'] as int? ?? lo;
          return r.total >= lo && r.total <= hi;
        }).firstOrNull;
      }
    } else {
      chosen = _pickWeighted(es, rng);
    }
    if (chosen == null) return DivinerResult('', dice: dice);
    final x = await expand(chosen);
    return DivinerResult(x.text, dice: dice, entryId: chosen['id'] as int, cycle: x.cycle, deep: x.deep);
  }

  /// Rolls a table and keeps it in the history (its last 200).
  Future<DivinerResult> roll(int tableId, [DiceRng? rng]) async {
    final r = await resolve(tableId, rng ?? _secureRng);
    await db.insert('diviner_roll', {'table_ref': tableId, 'dice_result': r.dice, 'entry_ref': r.entryId, 'result_text': r.text});
    await db.rawDelete(
        'DELETE FROM diviner_roll WHERE table_ref=? AND id NOT IN (SELECT id FROM diviner_roll WHERE table_ref=? ORDER BY id DESC LIMIT 200)',
        [tableId, tableId]);
    return r;
  }
}
