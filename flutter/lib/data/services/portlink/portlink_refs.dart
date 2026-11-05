import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/entity/entity_kinds.g.dart';

/// The shape of a vault database, read off the database itself — tables,
/// columns, foreign keys, UNIQUE column sets — so nothing here keeps its own
/// list of tables (Port Link, APP Plan.md Procress 32 part 9.3).
///
/// [owned] vs [shared]: a table is owned when a foreign-key chain leads from
/// it to `nexus` (103 of 111 tables at SDB 2.1.5) — its rows belong to one
/// Nexus. The rest (use_color, hashtag, timeline_date, …) are shared by every
/// Nexus in this app's single database: never deleted on a Nexus's behalf,
/// matched across files by their UNIQUE natural key.
class VaultShape {
  final List<String> tables;
  final Map<String, List<String>> cols;
  final Map<String, List<({String from, String table})>> fks;
  final Map<String, List<List<String>>> uniques;
  final Set<String> hasId;
  final Set<String> owned;

  VaultShape._(this.tables, this.cols, this.fks, this.uniques, this.hasId, this.owned);

  Set<String> get shared => tables.where((t) => !owned.contains(t)).toSet();

  static Future<VaultShape> of(DatabaseExecutor db) async {
    final all = await db.rawQuery("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'port_%' AND name NOT LIKE 'android_%'");
    // derived data (FTS and its shadow tables) is not content
    final virt = [for (final r in all) if (RegExp(r'^\s*CREATE\s+VIRTUAL', caseSensitive: false).hasMatch('${r['sql']}')) '${r['name']}'];
    final tables = [for (final r in all) '${r['name']}'].where((n) => !virt.any((v) => n == v || n.startsWith('${v}_'))).toList();
    final cols = <String, List<String>>{};
    final fks = <String, List<({String from, String table})>>{};
    final uniques = <String, List<List<String>>>{};
    final hasId = <String>{};
    for (final t in tables) {
      final info = await db.rawQuery('PRAGMA table_info("$t")');
      cols[t] = [for (final c in info) '${c['name']}'];
      if (info.any((c) => c['name'] == 'id' && c['pk'] == 1)) hasId.add(t);
      fks[t] = [for (final f in await db.rawQuery('PRAGMA foreign_key_list("$t")')) (from: '${f['from']}', table: '${f['table']}')];
      uniques[t] = [
        for (final i in await db.rawQuery('PRAGMA index_list("$t")'))
          if (i['unique'] == 1 && i['origin'] != 'pk') [for (final c in await db.rawQuery('PRAGMA index_info("${i['name']}")')) '${c['name']}'],
      ];
    }
    final owned = <String>{'nexus'};
    for (var grew = true; grew;) {
      grew = false;
      for (final t in tables) {
        if (!owned.contains(t) && fks[t]!.any((f) => f.table != t && owned.contains(f.table))) grew = owned.add(t);
      }
    }
    return VaultShape._(tables, cols, fks, uniques, hasId, owned);
  }

  /// Parents before children (a self-reference does not count), so ids a row
  /// points at are already mapped when it is written.
  List<String> topo() {
    final out = <String>[], seen = <String>{};
    void visit(String t, Set<String> stack) {
      if (seen.contains(t) || stack.contains(t)) return;
      stack.add(t);
      for (final f in fks[t]!) {
        if (f.table != t && cols.containsKey(f.table)) visit(f.table, stack);
      }
      seen.add(t);
      out.add(t);
    }

    for (final t in tables) {
      visit(t, {});
    }
    return out;
  }
}

/// Rewrites every stored id in a row through per-table maps (table → old id →
/// new id): foreign keys (from the schema), entity keys (SDB keyColumns) and
/// every other stored id (SDB idRefs) — the same set EXE's portlink-merge.js
/// follows. An id with no entry in its table's map is left as it is.
class RefRewriter {
  final VaultShape shape;
  final Map<String, Map<int, int>> maps;
  RefRewriter(this.shape, this.maps);

  static final Map<String, String> _prefixTable = {for (final f in entityFamilies) f.prefix: f.table};
  static final _keyRe = RegExp(r'^([a-z]+)_(\d+)$');

  Object? id(String table, Object? v) {
    final n = v is int ? v : (v is String ? int.tryParse(v) : null);
    if (n == null) return v;
    final to = maps[table]?[n];
    if (to == null) return v;
    return v is String ? '$to' : to; // an id kept as TEXT stays TEXT
  }

  String key(String k) {
    final m = _keyRe.firstMatch(k);
    if (m == null) return k;
    final t = _prefixTable[m.group(1)];
    if (t == null) return k;
    final to = maps[t]?[int.parse(m.group(2)!)];
    return to == null ? k : '${m.group(1)}_$to';
  }

  String _json(String s, Object? Function(Object?) fn) {
    try {
      return jsonEncode(fn(jsonDecode(s)));
    } catch (_) {
      return s;
    }
  }

  /// Rewrites [row] of [table] in place; also returns it.
  Map<String, Object?> rewrite(String table, Map<String, Object?> row) {
    final orig = Map<String, Object?>.of(row);
    for (final f in shape.fks[table] ?? const <({String from, String table})>[]) {
      if (row[f.from] != null) row[f.from] = id(f.table, row[f.from]);
    }
    for (final kc in keyColumns) {
      if (kc.table != table) continue;
      for (final c in kc.cols) {
        final v = row[c];
        if (v is! String) continue;
        if (kc.json) {
          row[c] = _json(v, (l) => l is List ? [for (final e in l) e is Map && e['key'] is String ? {...e, 'key': key(e['key'] as String)} : e] : l);
        } else if (kc.only == null || RegExp(kc.only!).hasMatch(v)) {
          row[c] = key(v);
        }
      }
    }
    for (final ir in idRefs) {
      if (ir.table != table || row[ir.col] == null) continue;
      if (ir.when != null && !ir.when!.values.contains('${orig[ir.when!.col]}')) continue;
      final v = row[ir.col];
      switch (ir.shape) {
        case 'id':
          row[ir.col] = id(ir.to!, v);
        case 'prefixedKey':
          if (v is String && v.startsWith(ir.prefix!)) row[ir.col] = ir.prefix! + key(v.substring(ir.prefix!.length));
        case 'jsonIdList':
          if (v is String) row[ir.col] = _json(v, (l) => l is List ? [for (final x in l) id(ir.to!, x)] : l);
        case 'jsonObjectIdLists':
          if (v is String) {
            row[ir.col] = _json(v, (o) {
              if (o is Map) {
                for (final k in ir.keys!) {
                  if (o[k] is List) o[k] = [for (final x in o[k] as List) id(ir.to!, x)];
                }
              }
              return o;
            });
          }
      }
    }
    return row;
  }
}
