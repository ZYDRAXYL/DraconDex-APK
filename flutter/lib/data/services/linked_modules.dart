import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../providers/db_providers.dart';
import '../dao/viewer_dao.dart';

/// A module another one is linked to, and how.
class LinkedModule {
  final int id;

  /// The module ↔ module relation row, when there is one — the link that
  /// can be removed from the page head; null when it comes only from a
  /// [[link]].
  final int? relationId;

  /// A [[link]] either way between the two.
  final bool wiki;
  const LinkedModule(this.id, {this.relationId, this.wiki = false});
}

/// Procress 28 part 6 — the modules a module is linked to, the same answer
/// as EXE db/viewer.js linkedModules: a module ↔ module relation
/// (`module_<a>` → `module_<b>` in entity_relation, either way), or a
/// `[[link]]` either way between anything of the two — the module itself
/// or one of its elements. The [[link]] side is read, never stored (D2):
/// remove the [[…]] and the link goes. Narrator, Author's point of view
/// and the Classifier relation view all read this.
///
/// Pure, so it is tested without a database: [relations] are
/// (id, from, to) rows, [wikiLinks] (src, target) rows, [ownerOf] the
/// module each key belongs to (a module key → itself).
List<LinkedModule> linkedModulesFrom(
  int moduleId, {
  required Iterable<(int, String, String)> relations,
  required Iterable<(String, String)> wikiLinks,
  required int? Function(String key) ownerOf,
}) {
  final self = 'module_$moduleId';
  final rel = <int, int>{};
  final wiki = <int>{};
  final order = <int>[];
  void seen(int id) {
    if (!rel.containsKey(id) && !wiki.contains(id)) order.add(id);
  }

  for (final (id, from, to) in relations) {
    if (from != self && to != self) continue;
    final m = RegExp(r'^module_(\d+)$').firstMatch(from == self ? to : from);
    final other = m == null ? null : int.parse(m[1]!);
    if (other == null || other == moduleId || rel.containsKey(other)) continue;
    seen(other);
    rel[other] = id;
  }
  for (final (src, target) in wikiLinks) {
    final a = ownerOf(src), b = ownerOf(target);
    final other = a == moduleId ? b : (b == moduleId ? a : null);
    if (other == null || other == moduleId || wiki.contains(other)) continue;
    seen(other);
    wiki.add(other);
  }
  return [for (final id in order) LinkedModule(id, relationId: rel[id], wiki: wiki.contains(id))];
}

Future<List<LinkedModule>> linkedModules(Database db, int nexusId, int moduleId) async {
  final self = 'module_$moduleId';
  final rels = await db.rawQuery('SELECT id, from_key, to_key FROM entity_relation WHERE from_key=? OR to_key=?', [self, self]);
  final links = await db.rawQuery('SELECT src_key, target_key FROM wiki_link WHERE target_key IS NOT NULL AND nexus_ref=?', [nexusId]);
  final owner = {for (final it in await ViewerDao(db).index(nexusId)) it.key: it.moduleId};
  return linkedModulesFrom(
    moduleId,
    relations: [for (final r in rels) (r['id'] as int, r['from_key'] as String, r['to_key'] as String)],
    wikiLinks: [for (final r in links) (r['src_key'] as String, r['target_key'] as String)],
    ownerOf: (k) => owner[k],
  );
}

final linkedModulesProvider = FutureProvider.autoDispose.family<List<LinkedModule>, ({int nexusId, int moduleId})>((ref, a) async {
  final db = await ref.watch(databaseProvider.future);
  return linkedModules(db, a.nexusId, a.moduleId);
});

/// Link two modules from the page head (a module ↔ module relation).
Future<void> linkModules(Database db, int nexusId, int moduleId, int otherId) => db.insert('entity_relation', {
      'nexus_ref': nexusId,
      'from_key': 'module_$moduleId',
      'to_key': 'module_$otherId',
    });

Future<void> unlinkModules(Database db, int relationId) => db.delete('entity_relation', where: 'id=?', whereArgs: [relationId]);
