import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../models/viewer_model.dart';

/// Data access for the Viewer and Connector kinds: the vault-wide item index
/// they filter over, the saved filter itself, and (for Connector) the
/// relations between filtered items.
class ViewerDao {
  final Database db;
  ViewerDao(this.db);

  // ---- the index ----------------------------------------------------------

  /// Every indexable row in the Nexus, as the desktop's `viewer.index` sees
  /// it. One UNION rather than six round trips, because a Viewer re-evaluates
  /// its filter on every open.
  ///
  /// Tags are attached afterwards for the two kinds that have link tables, so
  /// the union itself stays a flat select per source.
  Future<List<IndexedItem>> index(int nexusId) async {
    // module.handle came in with the desktop's handle work; a vault this app
    // created before then may not have the column, and a SELECT naming it
    // would fail the whole index — so it is read only when it exists.
    final moduleCols = await db.rawQuery('PRAGMA table_info(module)');
    final handleExpr = moduleCols.any((c) => c['name'] == 'handle') ? 'm.handle' : 'NULL';
    final sql = '''
      SELECT 'module_' || m.id AS key, 'module' AS item_kind, m.name AS name,
             m.id AS module_id, m.name AS module_name, m.kind AS module_kind,
             m.parent_id AS module_parent, uc.color_code AS color_code,
             $handleExpr AS handle
        FROM module m LEFT JOIN use_color uc ON m.color = uc.id
       WHERE m.nexus_ref = ?

      UNION ALL
      SELECT 'cobj_' || co.id, 'object', co.name,
             m.id, m.name, m.kind, m.parent_id, NULL, NULL
        FROM classifier_object co JOIN module m ON co.module_ref = m.id
       WHERE m.nexus_ref = ?

      UNION ALL
      SELECT 'tlev_' || te.id, 'event', COALESCE(te.event_name, ''),
             m.id, m.name, m.kind, m.parent_id, NULL, NULL
        FROM timeline_event te
        JOIN timeline t ON te.timeline_id = t.id
        JOIN module m ON t.module_ref = m.id
       WHERE m.nexus_ref = ?

      UNION ALL
      SELECT 'sdlg_' || sd.id, 'dialogue', sd.name,
             m.id, m.name, m.kind, m.parent_id, NULL, NULL
        FROM story_dialogue sd JOIN module m ON sd.module_ref = m.id
       WHERE m.nexus_ref = ?

      UNION ALL
      SELECT 'bchp_' || bc.id, 'chapter', bc.name,
             m.id, m.name, m.kind, m.parent_id, NULL, NULL
        FROM book_chapter bc JOIN module m ON bc.module_ref = m.id
       WHERE m.nexus_ref = ?

      UNION ALL
      SELECT 'chss_' || cs.id, 'chat', cs.name,
             m.id, m.name, m.kind, m.parent_id, NULL, NULL
        FROM chat_session cs JOIN module m ON cs.module_ref = m.id
       WHERE m.nexus_ref = ?
    ''';
    // Plain positional binds repeated once per UNION arm. SQLite would also
    // accept a numbered ?1 reused six times, but sqflite's argument handling
    // makes that a runtime-only gamble, and there is no Dart SDK here to test
    // it against — so bind it the unambiguous way.
    final rows = await db.rawQuery(sql, List.filled(6, nexusId));

    final moduleTags = await _moduleTags(nexusId);
    final eventTags = await _eventTags(nexusId);

    return rows.map((r) {
      final key = r['key'] as String;
      final itemKind = r['item_kind'] as String;
      return IndexedItem(
        key: key,
        itemKind: itemKind,
        name: r['name'] as String? ?? '',
        moduleId: r['module_id'] as int,
        moduleName: r['module_name'] as String? ?? '',
        moduleKind: r['module_kind'] as String? ?? 'collector',
        moduleParentId: r['module_parent'] as int?,
        colorCode: r['color_code'] as String?,
        handle: r['handle'] as String?,
        tags: switch (itemKind) {
          'module' => moduleTags[r['module_id'] as int] ?? const [],
          'event' => eventTags[int.parse(key.substring(5))] ?? const [],
          _ => const [],
        },
      );
    }).toList();
  }

  Future<Map<int, List<String>>> _moduleTags(int nexusId) async {
    final rows = await db.rawQuery('''
      SELECT mh.module_ref AS owner, h.tag_name AS tag
        FROM module_hashtag mh
        JOIN hashtag h ON mh.hashtag_id = h.id
        JOIN module m ON mh.module_ref = m.id
       WHERE m.nexus_ref = ?
    ''', [nexusId]);
    return _group(rows);
  }

  Future<Map<int, List<String>>> _eventTags(int nexusId) async {
    final rows = await db.rawQuery('''
      SELECT eh.event_id AS owner, h.tag_name AS tag
        FROM event_hashtag eh
        JOIN hashtag h ON eh.hashtag_id = h.id
        JOIN timeline_event te ON eh.event_id = te.id
        JOIN timeline t ON te.timeline_id = t.id
        JOIN module m ON t.module_ref = m.id
       WHERE m.nexus_ref = ?
    ''', [nexusId]);
    return _group(rows);
  }

  Map<int, List<String>> _group(List<Map<String, Object?>> rows) {
    final out = <int, List<String>>{};
    for (final r in rows) {
      (out[r['owner'] as int] ??= []).add(r['tag'] as String? ?? '');
    }
    return out;
  }

  // ---- the saved filter ---------------------------------------------------

  /// module_ui is a generic key/value side table; the filter lives under
  /// 'filterDef' as JSON, the same key and shape the desktop reads.
  Future<FilterDef> getFilterDef(int moduleRef) async {
    final rows = await db.query(
      'module_ui',
      columns: ['ui_value'],
      where: 'module_ref=? AND ui_key=?',
      whereArgs: [moduleRef, 'filterDef'],
      limit: 1,
    );
    if (rows.isEmpty) return const FilterDef();
    try {
      final raw = jsonDecode(rows.first['ui_value'] as String? ?? '{}');
      if (raw is Map<String, dynamic>) return FilterDef.fromJson(raw);
    } on FormatException {
      // A filter someone hand-edited into invalid JSON should show as "no
      // filter", not take the whole module down.
    }
    return const FilterDef();
  }

  Future<void> setFilterDef(int moduleRef, FilterDef def) async {
    await db.insert(
      'module_ui',
      {
        'module_ref': moduleRef,
        'ui_key': 'filterDef',
        'ui_value': jsonEncode(def.toJson()),
      },
      // UNIQUE(module_ref, ui_key) makes this an upsert.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- relations (Connector) ----------------------------------------------

  Future<List<Map<String, Object?>>> getRelations(int nexusId) async {
    return db.rawQuery('''
      SELECT er.id, er.from_key, er.to_key, er.label, uc.color_code
        FROM entity_relation er
        LEFT JOIN use_color uc ON er.color = uc.id
       WHERE er.nexus_ref = ? ORDER BY er.id
    ''', [nexusId]);
  }

  /// UNIQUE(from_key, to_key, label) — re-adding the same labelled edge is a
  /// no-op rather than an error.
  Future<void> addRelation({
    required int nexusId,
    required String fromKey,
    required String toKey,
    String? label,
  }) async {
    await db.insert(
      'entity_relation',
      {'nexus_ref': nexusId, 'from_key': fromKey, 'to_key': toKey, 'label': label},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteRelation(int id) async {
    await db.delete('entity_relation', where: 'id=?', whereArgs: [id]);
  }
}
