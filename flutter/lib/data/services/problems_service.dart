import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';

class Problem {
  final String type; // link | empty | relation
  final String? key;
  final String name;
  final String detail;
  const Problem(this.type, this.key, this.name, this.detail);
}

/// Problems (V5.md §11.10) — the port of EXE db/problems.js. Everything
/// worth a second look, read-only, each row naming where it is:
///   link      a [[link]] whose target does not exist
///   empty     a module of a content kind with nothing in it yet
///   relation  a relation (a relation field's value included) whose end is gone
/// All derived from the vendored ENTITY_KINDS, so a new family is covered.
class ProblemsService {
  static const maxPerType = 200;

  static Future<List<Problem>> list(DatabaseExecutor db, int nexusId) async {
    final names = <String, String?>{};
    Future<String?> nameOf(String key) async => names.containsKey(key) ? names[key] : names[key] = await EntityKinds.nameOf(db, key);
    Future<bool> exists(String key) async {
      final k = EntityKinds.parse(key);
      final f = k == null ? null : EntityKinds.byPrefix[k.$1];
      if (f == null) return true; // a family this app does not know is not ours to judge
      try {
        return (await db.rawQuery('SELECT 1 FROM ${f.table} WHERE id=?', [k!.$2])).isNotEmpty;
      } catch (_) {
        return true;
      }
    }

    final out = <Problem>[];

    // Unresolved [[links]], one row per source.
    final bySrc = <String, List<String>>{};
    for (final r in await db.rawQuery(
        'SELECT src_key, target_text FROM wiki_link WHERE nexus_ref=? AND target_key IS NULL ORDER BY src_key', [nexusId])) {
      (bySrc[r['src_key'] as String] ??= []).add(r['target_text'] as String? ?? '');
    }
    for (final e in bySrc.entries.take(maxPerType)) {
      out.add(Problem('link', e.key, await nameOf(e.key) ?? e.key, {for (final t in e.value) '[[$t]]'}.join(' ')));
    }

    // Empty content modules: a kind's content family is the one whose lookup
    // names that kind; Drafter / Inspector hold their text in the module.
    final familyOf = <String, EntityFamily>{};
    for (final f in entityFamilies) {
      if (f.owner != null && !const {'module', 'ctpl', 'exn'}.contains(f.prefix)) familyOf.putIfAbsent(f.lookupModule, () => f);
    }
    var empties = 0;
    for (final m in await db.rawQuery(
        'SELECT id, name, kind, description FROM module WHERE nexus_ref=? ORDER BY display_order, id', [nexusId])) {
      final kind = m['kind'] as String;
      var empty = false;
      if (kind == 'drafter' || kind == 'inspector') {
        empty = ((m['description'] as String?) ?? '').trim().isEmpty;
      } else if (familyOf[kind] != null) {
        empty = (await db.rawQuery(familyOf[kind]!.owner!, [m['id']])).isEmpty;
      }
      if (empty) {
        out.add(Problem('empty', 'module_${m['id']}', m['name'] as String, kind));
        if (++empties >= maxPerType) break;
      }
    }

    // Relations with a missing end.
    var n = 0;
    for (final r in await db.rawQuery(
        'SELECT from_key, to_key, rel_type, label FROM entity_relation WHERE nexus_ref=? ORDER BY id', [nexusId])) {
      final from = r['from_key'] as String, to = r['to_key'] as String;
      final fromOk = await exists(from), toOk = await exists(to);
      if (fromOk && toOk) continue;
      final rt = r['rel_type'] as String?;
      final field = rt != null && RegExp(r'^ctpl_\d+$').hasMatch(rt) ? await nameOf(rt) : null;
      final live = fromOk ? from : to;
      final anyOk = fromOk || toOk;
      out.add(Problem(
        'relation',
        anyOk ? live : null,
        anyOk ? (await nameOf(live) ?? live) : '—',
        [field ?? rt ?? (r['label'] as String?) ?? '', '→ ${fromOk ? to : from}'].where((s) => s.isNotEmpty).join(' '),
      ));
      if (++n >= maxPerType) break;
    }
    return out;
  }
}
