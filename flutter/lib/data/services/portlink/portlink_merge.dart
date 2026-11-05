import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'portlink_refs.dart';

/// One cell both sides changed differently since the base — the user picks
/// (APP Plan.md Procress 32: "ask every time"). [key] is `table:id:col`, the
/// same key EXE uses and `choices` answers.
class PortlinkConflict {
  final String key, table, col;
  final int id;
  final Object? base, local, drive;
  final String? label, localAt, driveAt;
  const PortlinkConflict({
    required this.key,
    required this.table,
    required this.id,
    required this.col,
    this.base,
    this.local,
    this.drive,
    this.label,
    this.localAt,
    this.driveAt,
  });
}

class PortlinkMergeResult {
  final List<PortlinkConflict> conflicts;
  final Map<String, int> summary;
  const PortlinkMergeResult(this.conflicts, this.summary);
}

/// The 3-way merge of one Nexus (Plan part 9.4) — a port of EXE's
/// `electron/src/db/portlink-merge.js mergeInto`, held to the same cases
/// (SDB `fixtures/portlink-merge-v1.json`, run by
/// `test/portlink_fixture_test.dart`). A rule changes in SDB first.
///
/// Three vault files in the DRIVE's ids (this app's side comes out of
/// [PortlinkCodec.extract] already renumbered):
///   [b] the base — what the drive held at the last sync
///   [l] this phone's Nexus, edited since
///   [w] a scratch copy of the drive's file, edited since; L's changes are laid
///       on top, so the drive's ids never move (the drive is the hub)
///
/// Per row, against B: changed on one side → that side; on both → per
/// column, a column both changed differently is a [PortlinkConflict] unless
/// [choices] answers it (`'table:id:col'` or `'*'` → `'local'`/`'drive'`);
/// deleted on one, edited on the other → kept; new here → added, renumbered
/// if the drive made the same id meanwhile, or matched by a UNIQUE (a tag
/// both made). Join tables are sets.
///
/// A renumber is followed by every column W took from L — and ONLY those,
/// mapped once from L's own value: the rest of a row is the drive's, its ids
/// are W's already (SDB case `drive-ref-stays`).
Future<PortlinkMergeResult> mergeInto(Database b, Database l, Database w, {Map<String, String> choices = const {}}) async {
  final ws = await VaultShape.of(w), ls = await VaultShape.of(l);
  final tables = ws.tables.where(ls.tables.contains).toSet();
  final bT = {for (final r in await b.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")) '${r['name']}'};
  final cols = {for (final t in tables) t: ws.cols[t]!.where(ls.cols[t]!.contains).toList()};
  final order = ws.topo().where(tables.contains).toList();
  final idMap = <String, Map<int, int>>{}; // table → L id → W id, rows that had to move
  final rw = RefRewriter(ws, idMap);
  final conflicts = <PortlinkConflict>[];
  final written = <(String, int, Map<String, Object?>, List<String>)>[]; // table, W id, L row, columns taken from it
  final sum = {for (final k in ['fromLocal', 'updated', 'deleted', 'kept', 'merged', 'conflicts', 'driveAdded', 'driveChanged', 'driveRemoved']) k: 0};

  Map<String, Object?> mapFks(String t, Map<String, Object?> r) {
    for (final f in ws.fks[t]!) {
      if (r[f.from] != null) r[f.from] = rw.id(f.table, r[f.from]);
    }
    return r;
  }

  Future<void> run(Transaction tx) async {
    Future<List<Map<String, Object?>>> rows(DatabaseExecutor d, String t) async =>
        [for (final r in await d.rawQuery('SELECT * FROM ${_q(t)}')) Map<String, Object?>.of(r)];
    Map<int, Map<String, Object?>> byId(List<Map<String, Object?>> rs) => {for (final r in rs) r['id']! as int: r};
    Future<void> insert(String t, Map<String, Object?> r, {bool orIgnore = false}) async {
      final c = cols[t]!.where(r.containsKey).toList();
      await tx.rawInsert('INSERT ${orIgnore ? 'OR IGNORE ' : ''}INTO ${_q(t)} (${c.map(_q).join(',')}) VALUES (${c.map((_) => '?').join(',')})', [for (final x in c) r[x]]);
    }

    Future<void> update(String t, int id, Map<String, Object?> r, List<String> cs) async {
      if (cs.isEmpty) return;
      await tx.rawUpdate('UPDATE ${_q(t)} SET ${cs.map((c) => '${_q(c)}=?').join(',')} WHERE id=?', [for (final c in cs) r[c], id]);
    }

    final deletes = <(String, int)>[];
    for (final t in order) {
      final cs = cols[t]!;
      final br = bT.contains(t) ? await rows(b, t) : <Map<String, Object?>>[];
      if (!ws.hasId.contains(t)) {
        // a join table: sets of rows
        final bs = {for (final r in br) _tuple(r, cs)};
        final lr = await rows(l, t);
        final lk = {for (final r in lr) _tuple(r, cs)};
        for (final r in lr) {
          if (bs.contains(_tuple(r, cs))) continue;
          try {
            await insert(t, mapFks(t, r), orIgnore: true);
            sum['fromLocal'] = sum['fromLocal']! + 1;
          } on DatabaseException catch (_) {}
        }
        for (final r in br) {
          if (lk.contains(_tuple(r, cs))) continue;
          await tx.rawDelete('DELETE FROM ${_q(t)} WHERE ${cs.map((c) => '${_q(c)} IS ?').join(' AND ')}', [for (final c in cs) r[c]]);
        }
        continue;
      }
      final bm = byId(br), lm = byId(await rows(l, t)), dm = byId(await rows(tx, t));
      final vc = cs.where((c) => c != 'id').toList();
      for (final e in dm.entries) {
        final x = bm[e.key];
        if (x == null) {
          sum['driveAdded'] = sum['driveAdded']! + 1;
        } else if (vc.any((c) => !_same(e.value[c], x[c]))) {
          sum['driveChanged'] = sum['driveChanged']! + 1;
        }
      }
      sum['driveRemoved'] = sum['driveRemoved']! + bm.keys.where((id) => !dm.containsKey(id)).length;
      var nextId = [0, ...bm.keys, ...lm.keys, ...dm.keys].reduce((a, c) => a > c ? a : c) + 1;

      for (final e in lm.entries) {
        final id = e.key, lr = e.value, base = bm[id], dr = dm[id];
        if (base == null) {
          // new on this phone
          final r = mapFks(t, Map.of(lr));
          var wid = id;
          if (dr != null) {
            wid = nextId++;
            r['id'] = wid;
            (idMap[t] ??= {})[id] = wid;
          }
          try {
            await insert(t, r);
            written.add((t, wid, lr, vc));
            sum['fromLocal'] = sum['fromLocal']! + 1;
          } on DatabaseException {
            // a UNIQUE says the drive already has it (both made the same tag …): that row it is
            final u = ws.uniques[t]!.where((us) => us.every((c) => r[c] != null)).firstOrNull;
            final ex = u == null
                ? null
                : (await tx.rawQuery('SELECT * FROM ${_q(t)} WHERE ${u.map((c) => '${_q(c)}=?').join(' AND ')}', [for (final c in u) r[c]])).firstOrNull;
            if (ex == null) rethrow;
            final exId = ex['id']! as int;
            (idMap[t] ??= {})[id] = exId;
            if ('${lr['update_at'] ?? ''}'.compareTo('${ex['update_at'] ?? ''}') > 0) {
              final up = vc.where((c) => !u!.contains(c) && !_same(r[c], ex[c])).toList();
              await update(t, exId, r, up);
              written.add((t, exId, lr, up));
            }
            sum['merged'] = sum['merged']! + 1;
          }
          continue;
        }
        final lc = vc.where((c) => !_same(lr[c], base[c])).toList();
        if (lc.isEmpty) continue; // unchanged here: W (= the drive) already has the answer
        if (dr == null) {
          // the drive deleted it, this phone edited it: kept
          await insert(t, mapFks(t, Map.of(lr)));
          written.add((t, id, lr, vc));
          sum['kept'] = sum['kept']! + 1;
          continue;
        }
        final r = mapFks(t, Map.of(lr));
        final take = <String>[];
        for (final c in lc) {
          if (_same(dr[c], base[c]) || _same(dr[c], r[c])) {
            take.add(c);
            continue;
          }
          if (c == 'update_at') {
            if ('${r[c]}'.compareTo('${dr[c]}') > 0) take.add(c);
            continue;
          }
          final k = '$t:$id:$c';
          final choice = choices[k] ?? choices['*'];
          if (choice == 'local') {
            take.add(c);
          } else if (choice != 'drive') {
            conflicts.add(PortlinkConflict(
              key: k, table: t, id: id, col: c, base: base[c], local: lr[c], drive: dr[c],
              label: (lr['name'] ?? lr['title'] ?? dr['name'] ?? dr['title'])?.toString(),
              localAt: lr['update_at']?.toString(), driveAt: dr['update_at']?.toString(),
            ));
          }
        }
        await update(t, id, r, take);
        if (take.isNotEmpty) {
          written.add((t, id, lr, take));
          sum['updated'] = sum['updated']! + 1;
        }
      }
      for (final e in bm.entries) {
        final id = e.key;
        if (lm.containsKey(id) || !dm.containsKey(id)) continue;
        // deleted here; deleted from W only if the drive left it as it was
        if (vc.every((c) => _same(dm[id]![c], e.value[c]))) {
          deletes.add((t, id));
        } else {
          sum['kept'] = sum['kept']! + 1;
        }
      }
    }
    for (final (t, id) in deletes) {
      await tx.rawDelete('DELETE FROM ${_q(t)} WHERE id=?', [id]);
      sum['deleted'] = sum['deleted']! + 1;
    }

    // References: the columns W took from L, mapped once from L's value
    // (FKs again too — a parent in the same table may have moved after its
    // child went in). Nothing else in the row: that is the drive's.
    if (idMap.isNotEmpty) {
      for (final (t, id, lr, from) in written) {
        final cur = (await tx.rawQuery('SELECT * FROM ${_q(t)} WHERE id=?', [id])).firstOrNull;
        if (cur == null) continue;
        final m = rw.rewrite(t, Map.of(lr));
        final up = from.where((c) => !_same(m[c], cur[c])).toList();
        await update(t, id, m, up);
      }
    }

    // Integrity: a row pointing at a parent the merge removed gets the parent
    // back (from L, or from the base); one whose parent exists nowhere is
    // dropped. Until nothing changes.
    for (var pass = 0; pass < 50; pass++) {
      final bad = await tx.rawQuery('PRAGMA foreign_key_check');
      if (bad.isEmpty) break;
      var fixed = false;
      for (final v in bad) {
        final table = '${v['table']}', parent = '${v['parent']}';
        final fk = (await tx.rawQuery('PRAGMA foreign_key_list(${_q(table)})')).where((f) => f['id'] == v['fkid']).firstOrNull;
        final child = (await tx.rawQuery('SELECT * FROM ${_q(table)} WHERE rowid=?', [v['rowid']])).firstOrNull;
        if (fk == null || child == null) continue;
        final pid = child['${fk['from']}'];
        Map<String, Object?>? src;
        if (ws.hasId.contains(parent) && cols.containsKey(parent)) {
          src = (await l.rawQuery('SELECT * FROM ${_q(parent)} WHERE id=?', [pid])).firstOrNull ??
              (bT.contains(parent) ? (await b.rawQuery('SELECT * FROM ${_q(parent)} WHERE id=?', [pid])).firstOrNull : null);
        }
        if (src != null && (await tx.rawQuery('SELECT 1 FROM ${_q(parent)} WHERE id=?', [pid])).isEmpty) {
          await insert(parent, mapFks(parent, Map.of(src)));
          sum['kept'] = sum['kept']! + 1;
          if (sum['deleted']! > 0) sum['deleted'] = sum['deleted']! - 1;
        } else {
          await tx.rawDelete('DELETE FROM ${_q(table)} WHERE rowid=?', [v['rowid']]);
        }
        fixed = true;
      }
      if (!fixed) break;
    }
  }

  await w.execute('PRAGMA foreign_keys = OFF');
  try {
    await w.transaction(run);
  } finally {
    await w.execute('PRAGMA foreign_keys = ON');
  }
  sum['conflicts'] = conflicts.length;
  return PortlinkMergeResult(conflicts, sum);
}

String _q(String n) => '"${n.replaceAll('"', '""')}"';

bool _same(Object? a, Object? b) {
  if (a is Uint8List || b is Uint8List) {
    if (a is! Uint8List || b is! Uint8List || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}

String _tuple(Map<String, Object?> r, List<String> cols) =>
    jsonEncode([for (final c in cols) r[c] is Uint8List ? base64Encode(r[c]! as Uint8List) : r[c]]);
