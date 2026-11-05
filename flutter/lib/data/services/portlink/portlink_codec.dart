import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/vault_schema.g.dart';
import '../../dao/port_link_dao.dart';
import 'portlink_refs.dart';

/// The rows of one Nexus out of this app's single database: [owned] by table
/// (id tables keyed by id; join tables as a list), plus the [shared] rows they
/// point at (use_color, hashtag, …).
class NexusRows {
  final Map<String, Map<int, Map<String, Object?>>> byId = {};
  final Map<String, List<Map<String, Object?>>> joins = {};
  Set<int> ids(String t) => byId[t]?.keys.toSet() ?? <int>{};
}

/// A link's row map no longer describes the Nexus: most of the rows it names
/// are gone (a whole-Nexus import over a linked Nexus gives every row a new
/// id). Syncing would read them as deleted here and delete them on the drive,
/// so nothing is synced — the user decides.
class PortlinkMapBroken implements Exception {
  final int mapped, missing;
  PortlinkMapBroken(this.mapped, this.missing);
  @override
  String toString() => 'PortlinkMapBroken($missing of $mapped mapped rows are gone)';
}

/// Port Link on Android (APP Plan.md Procress 32 part 9.3) — between this
/// app's single `novel-manager.db` and a drive's per-Nexus vault file.
///
///   [extract]  one Nexus → a vault file in the DRIVE's ids (the "L" of the
///              merge): rows the link's map knows take their drive id; rows
///              made here since take ids above everything the base holds, so
///              the merge sees them as new, never as a base row.
///   [absorb]   a vault file in the drive's ids → this Nexus's rows here, in
///              this database's ids: a mapped row keeps its local id, a new
///              one gets the next free id; the map is rewritten to match.
///
/// Every stored id moves through [RefRewriter] — FKs, entity keys, idRefs —
/// the same set EXE's merge follows.
class PortlinkCodec {
  final DatabaseExecutor db;
  PortlinkCodec(this.db);

  /// The Nexus's rows: owned ones by following foreign keys down from the
  /// `nexus` row; shared ones they point at, by following them up.
  /// ponytail: reads each table whole — the phone's whole database, once per
  /// sync. A per-table WHERE … IN (…) if that ever shows up in a profile.
  Future<NexusRows> rowsOf(VaultShape shape, int nexusId) async {
    final out = NexusRows();
    final cache = <String, List<Map<String, Object?>>>{};
    Future<List<Map<String, Object?>>> all(String t) async => cache[t] ??= [for (final r in await db.query(t)) Map<String, Object?>.of(r)];
    final nx = (await db.query('nexus', where: 'id = ?', whereArgs: [nexusId]));
    if (nx.isEmpty) return out;
    out.byId['nexus'] = {nexusId: Map<String, Object?>.of(nx.first)};
    final joinKeys = <String, Set<String>>{};
    for (var grew = true; grew;) {
      grew = false;
      for (final t in shape.owned) {
        if (t == 'nexus') continue;
        for (final r in await all(t)) {
          final mine = shape.fks[t]!.any((f) => shape.owned.contains(f.table) && out.ids(f.table).contains(r[f.from]));
          if (!mine) continue;
          if (shape.hasId.contains(t)) {
            final m = out.byId[t] ??= {};
            if (!m.containsKey(r['id'])) {
              m[r['id']! as int] = r;
              grew = true;
            }
          } else {
            final k = jsonEncode(_canon(r));
            if ((joinKeys[t] ??= {}).add(k)) {
              (out.joins[t] ??= []).add(r);
              grew = true;
            }
          }
        }
      }
    }
    // shared rows the owned ones point at — and the shared rows THOSE point at
    for (var grew = true; grew;) {
      grew = false;
      for (final t in [...out.byId.keys, ...out.joins.keys]) {
        final rows = [...?out.byId[t]?.values, ...?out.joins[t]];
        for (final f in shape.fks[t]!) {
          if (!shape.shared.contains(f.table)) continue;
          final want = {for (final r in rows) if (r[f.from] is int) r[f.from]! as int}..removeAll(out.ids(f.table));
          if (want.isEmpty) continue;
          for (final r in await all(f.table)) {
            if (want.contains(r['id'])) {
              (out.byId[f.table] ??= {})[r['id']! as int] = r;
              grew = true;
            }
          }
        }
      }
    }
    return out;
  }

  /// Refuses (throws [PortlinkMapBroken]) when the map names rows that are
  /// mostly gone. "Mostly": every mapped module, or over half of all mapped
  /// rows once there are more than 10 — a big delete still syncs, a Nexus
  /// replaced from a snapshot does not.
  static void checkMap(Map<String, Map<int, int>> l2d, NexusRows rows) {
    var mapped = 0, missing = 0;
    for (final e in l2d.entries) {
      if (e.key == 'nexus') continue;
      final have = rows.ids(e.key);
      mapped += e.value.length;
      missing += e.value.keys.where((id) => !have.contains(id)).length;
    }
    final mods = l2d['module'] ?? const {};
    final noModuleLeft = mods.isNotEmpty && mods.keys.every((id) => !rows.ids('module').contains(id));
    if (noModuleLeft || (mapped > 10 && missing * 2 > mapped)) throw PortlinkMapBroken(mapped, missing);
  }

  /// One Nexus → a new vault file at [outPath] in the drive's ids.
  /// [baseMaxIds]: per table, the largest id in the link's base file — a row
  /// new here must get an id above it. → the full local → drive map used.
  Future<Map<String, Map<int, int>>> extract({
    required int nexusId,
    required int driveNexusId,
    required String outPath,
    required Map<String, Map<int, int>> l2d,
    Map<String, int> baseMaxIds = const {},
    required DatabaseFactory factory,
  }) async {
    final shape = await VaultShape.of(db);
    final rows = await rowsOf(shape, nexusId);
    checkMap(l2d, rows);
    final maps = <String, Map<int, int>>{for (final e in l2d.entries) e.key: Map.of(e.value)};
    maps['nexus'] = {nexusId: driveNexusId};
    for (final t in rows.byId.keys) {
      final m = maps[t] ??= {};
      var next = [baseMaxIds[t] ?? 0, ...m.values].fold<int>(0, (a, b) => a > b ? a : b) + 1;
      final ids = rows.byId[t]!.keys.toList()..sort();
      for (final id in ids) {
        if (!m.containsKey(id)) m[id] = next++;
      }
      // a mapped row that is gone here leaves its entry; the merge reads its absence as a delete
    }
    final rw = RefRewriter(shape, maps);
    await factory.deleteDatabase(outPath);
    final out = await factory.openDatabase(outPath, options: OpenDatabaseOptions(singleInstance: false));
    try {
      for (final sql in vaultCreateStatements) {
        await out.execute(sql);
      }
      final outCols = <String, Set<String>>{};
      final batch = out.batch();
      for (final t in shape.topo()) {
        final cs = outCols[t] ??= {for (final c in await out.rawQuery('PRAGMA table_info("$t")')) '${c['name']}'};
        if (cs.isEmpty) continue; // a table this app has and the vault DDL does not
        for (final r in [...?rows.byId[t]?.values, ...?rows.joins[t]]) {
          final w = rw.rewrite(t, Map<String, Object?>.of(r));
          if (shape.hasId.contains(t)) w['id'] = maps[t]![r['id']]!;
          w.removeWhere((k, _) => !cs.contains(k));
          batch.insert(t, w);
        }
      }
      await batch.commit(noResult: true);
    } finally {
      await out.close();
    }
    return maps;
  }

  /// A vault file in the drive's ids → this Nexus's rows here. Replaces the
  /// Nexus's owned rows (the `nexus` row itself is updated, never replaced);
  /// shared rows are matched by their UNIQUE key and only added, never
  /// changed — another Nexus may be using them. [d2l]: what the link knew
  /// (empty for a first clone from the drive). → the new local → drive map,
  /// already written to [linkUid]'s row map when one is given.
  Future<Map<String, Map<int, int>>> absorb({
    required String filePath,
    required int nexusId,
    required int driveNexusId,
    required Map<String, Map<int, int>> d2l,
    required DatabaseFactory factory,
    String? linkUid,
  }) async {
    final shape = await VaultShape.of(db);
    final src = await factory.openDatabase(filePath, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    final w = <String, List<Map<String, Object?>>>{};
    try {
      final have = {for (final r in await src.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")) '${r['name']}'};
      for (final t in shape.tables) {
        if (have.contains(t)) w[t] = [for (final r in await src.query(t)) Map<String, Object?>.of(r)];
      }
    } finally {
      await src.close();
    }
    final current = await rowsOf(shape, nexusId);
    final maps = <String, Map<int, int>>{for (final e in d2l.entries) e.key: Map.of(e.value)};
    maps['nexus'] = {driveNexusId: nexusId};
    final rw = RefRewriter(shape, maps);
    final newShared = <String, List<Map<String, Object?>>>{};

    // 1. local ids for every drive row, parents first
    for (final t in shape.topo()) {
      if (!shape.hasId.contains(t) || t == 'nexus' || w[t] == null) continue;
      final m = maps[t] ??= {};
      final used = {for (final r in await db.rawQuery('SELECT id FROM "$t"')) r['id']! as int};
      var next = used.fold<int>(0, (a, b) => a > b ? a : b) + 1;
      final mine = current.ids(t);
      for (final r in w[t]!) {
        final did = r['id']! as int;
        if (shape.shared.contains(t)) {
          final probe = rw.rewrite(t, Map<String, Object?>.of(r)); // its own FKs (a tag's colour) in local ids
          Map<String, Object?>? hit;
          for (final u in shape.uniques[t]!) {
            if (u.any((c) => probe[c] == null)) continue;
            final q = await db.query(t, where: u.map((c) => '"$c" = ?').join(' AND '), whereArgs: [for (final c in u) probe[c]], limit: 1);
            if (q.isNotEmpty) {
              hit = q.first;
              break;
            }
          }
          if (hit != null) {
            m[did] = hit['id']! as int;
          } else if (m[did] != null && used.contains(m[did])) {
            // mapped before and still there
          } else {
            m[did] = next++;
            (newShared[t] ??= []).add(r);
          }
        } else {
          // owned: keep the local id we had for it — unless another Nexus's row holds it now
          final had = m[did];
          if (had == null || (used.contains(had) && !mine.contains(had))) m[did] = next++;
        }
      }
    }

    // 2. replace the Nexus's owned rows, in one transaction
    Future<void> body(DatabaseExecutor txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final t in shape.topo().reversed) {
        if (!shape.owned.contains(t) || t == 'nexus') continue;
        if (shape.hasId.contains(t)) {
          for (final id in current.ids(t)) {
            await txn.delete(t, where: 'id = ?', whereArgs: [id]);
          }
        } else {
          for (final r in current.joins[t] ?? const <Map<String, Object?>>[]) {
            final cs = shape.cols[t]!;
            await txn.delete(t, where: cs.map((c) => '"$c" IS ?').join(' AND '), whereArgs: [for (final c in cs) r[c]]);
          }
        }
      }
      for (final t in shape.topo()) {
        final cs = shape.cols[t]!.toSet();
        if (t == 'nexus') {
          final dn = (w['nexus'] ?? const []).where((r) => r['id'] == driveNexusId);
          if (dn.isEmpty) continue;
          final v = rw.rewrite(t, Map<String, Object?>.of(dn.first))..remove('id');
          v.removeWhere((k, _) => !cs.contains(k));
          // nexus.name is UNIQUE across every Nexus here: the drive's name is
          // taken only while no other Nexus on this phone has it
          if (v['name'] != null &&
              (await txn.query('nexus', columns: ['id'], where: 'name = ? AND id <> ?', whereArgs: [v['name'], nexusId], limit: 1)).isNotEmpty) {
            v.remove('name');
          }
          await txn.update('nexus', v, where: 'id = ?', whereArgs: [nexusId]);
          continue;
        }
        final rowsIn = shape.shared.contains(t) ? (newShared[t] ?? const []) : (w[t] ?? const []);
        for (final r in rowsIn) {
          final v = rw.rewrite(t, Map<String, Object?>.of(r));
          if (shape.hasId.contains(t)) v['id'] = maps[t]![r['id']]!;
          v.removeWhere((k, _) => !cs.contains(k));
          await txn.insert(t, v, conflictAlgorithm: shape.hasId.contains(t) ? ConflictAlgorithm.abort : ConflictAlgorithm.ignore);
        }
      }
      final l2d = {
        for (final e in maps.entries)
          if (e.key != 'nexus') e.key: {for (final x in e.value.entries) x.value: x.key},
      };
      if (linkUid != null) await PortLinkDao(txn).replaceMaps(linkUid, l2d);
    }

    final d = db;
    if (d is Database) {
      await d.transaction(body);
    } else {
      await body(d);
    }
    return {
      for (final e in maps.entries) e.key: {for (final x in e.value.entries) x.value: x.key},
    };
  }

  /// "Has this Nexus changed since the last sync?" — a hash of its owned rows
  /// (there is no file of its own to stat here). Same content → same value.
  Future<String> fingerprint(int nexusId) async {
    final shape = await VaultShape.of(db);
    final rows = await rowsOf(shape, nexusId);
    final b = StringBuffer();
    for (final t in (shape.owned.toList()..sort())) {
      final rs = [...?rows.byId[t]?.values, ...?rows.joins[t]].map((r) => jsonEncode(_canon(r))).toList()..sort();
      b
        ..writeln(t)
        ..writeAll(rs, '\n')
        ..writeln();
    }
    return 'fp:${sha256.convert(utf8.encode(b.toString()))}';
  }

  static Map<String, Object?> _canon(Map<String, Object?> r) {
    final keys = r.keys.toList()..sort();
    return {for (final k in keys) k: r[k] is Uint8List ? base64Encode(r[k]! as Uint8List) : r[k]};
  }
}
