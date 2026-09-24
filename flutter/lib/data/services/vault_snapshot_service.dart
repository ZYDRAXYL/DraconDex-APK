import 'package:sqflite/sqflite.dart';

/// The `dracondex-vault-snapshot` format — the Dart half of a contract whose
/// other half is `serializeVault` / `applySnapshotCore` in
/// `electron/src/db/sync.js` (DraconDex-EXE).
///
/// This exists because the two apps cannot exchange raw database files.
/// DraconDex-EXE keeps one `.ddx` per Nexus (see `docs/VAULTS.md`); this app
/// still keeps every Nexus in a single `novel-manager.db`, and the web build
/// keeps it in IndexedDB with no file at all. The snapshot is the interchange
/// format both sides can speak, and it is what DDX Transfer and the desktop's
/// own export/import already move around.
///
/// **The JSON here must match the JS byte for byte.** A mismatch does not
/// throw; it lands a vault that imports with pieces silently missing. Every
/// query below is a deliberate transliteration of its JS original — same
/// joins, same aliases, same ORDER BY — and the order of the inserts in
/// [applySnapshot] is a dependency order, not a stylistic one.
class VaultSnapshotService {
  static const String format = 'dracondex-vault-snapshot';
  /// v2 (APP docs/V5.md §12): `pageBlocks` replaces `moduleAttrs`. A v1
  /// snapshot still imports — its attributes become property blocks.
  static const int version = 2;
  static const Set<int> readableVersions = {1, 2};

  /// The natural key a `timeline_date` row is deduplicated by, matching
  /// `dateKey` in sync.js exactly — it ends up in the JSON, so the separator
  /// and field order are part of the format.
  static String dateKey(Map<String, Object?> d) =>
      '${d['day']}|${d['month']}|${d['years']}|${d['hour']}|${d['minute']}';

  static bool validate(Object? payload) {
    if (payload is! Map) return false;
    if (payload['format'] != format || !readableVersions.contains(payload['version'])) return false;
    return payload['modules'] is List && payload['nexus'] is Map;
  }

  // ---------------------------------------------------------------------
  // Serialize
  // ---------------------------------------------------------------------

  /// Reads one Nexus into a single JSON-shaped map.
  ///
  /// [moduleIds] scopes the snapshot to a module subtree instead of the whole
  /// Nexus, exactly as the JS does: every query below reaches `module m` and
  /// filters `m.nexus_ref=?`, and in scoped mode that one substring is swapped
  /// for `m.id IN (...)`. Vault-global sections (relations, notes, calendar
  /// templates) are skipped entirely when scoped — a single module cannot
  /// carry the whole vault's notes.
  static Future<Map<String, Object?>?> serializeVault(
    DatabaseExecutor db,
    int nexusId, {
    List<int>? moduleIds,
  }) async {
    final nexusRows = await db.rawQuery('''
      SELECT n.name, n.memo, c.color_code AS colorCode
      FROM nexus n LEFT JOIN use_color c ON n.color = c.id WHERE n.id=?''', [nexusId]);
    if (nexusRows.isEmpty) return null;
    final nexus = nexusRows.first;

    final scoped = moduleIds != null && moduleIds.isNotEmpty;

    Future<List<Map<String, Object?>>> all(String sql) {
      if (scoped) {
        final inClause = 'm.id IN (${List.filled(moduleIds.length, '?').join(',')})';
        return db.rawQuery(sql.replaceFirst('m.nexus_ref=?', inClause), moduleIds);
      }
      return db.rawQuery(sql, [nexusId]);
    }

    Future<List<Map<String, Object?>>> allGlobal(String sql) async =>
        scoped ? <Map<String, Object?>>[] : db.rawQuery(sql, [nexusId]);

    final modules = await all('''
      SELECT m.id, m.parent_id AS parentId, m.name, m.kind, m.icon,
             ic.color_code AS iconColorCode, cc.color_code AS colorCode,
             m.description, m.display_order AS displayOrder, m.pinned,
             m.cat_type AS catType, m.handle, m.create_at AS createAt, m.update_at AS updateAt
      FROM module m
      LEFT JOIN use_color ic ON m.icon_color = ic.id
      LEFT JOIN use_color cc ON m.color = cc.id
      WHERE m.nexus_ref=? ORDER BY m.id''');

    // Same shape as serializeVault's pageBlocks in EXE's db/sync.js.
    final pageBlocks = await all('''
      SELECT b.id, b.module_ref AS moduleId, b.item_key AS itemKey, b.parent_id AS parentId,
             b.block_type AS type, b.component, b.source_key AS sourceKey, b.config,
             b.content, b.prop_name AS propName, b.prop_type AS propType,
             b.block_order AS "order"
      FROM page_block b JOIN module m ON b.module_ref=m.id
      WHERE m.nexus_ref=? ORDER BY b.id''');

    final moduleUi = await all('''
      SELECT u.module_ref AS moduleId, u.ui_key AS key, u.ui_value AS value
      FROM module_ui u JOIN module m ON u.module_ref=m.id WHERE m.nexus_ref=?''');

    final moduleTags = await all('''
      SELECT mh.module_ref AS moduleId, h.tag_name AS tagName, hc.color_code AS colorCode
      FROM module_hashtag mh
      JOIN module m ON mh.module_ref=m.id
      JOIN hashtag h ON mh.hashtag_id=h.id
      LEFT JOIN use_color hc ON h.tag_color=hc.id
      WHERE m.nexus_ref=?''');

    final classifier = <String, Object?>{
      'objects': await all('''
        SELECT o.id, o.module_ref AS moduleId, o.name, c.color_code AS colorCode,
               o.note, o.display_order AS displayOrder
        FROM classifier_object o JOIN module m ON o.module_ref=m.id
        LEFT JOIN use_color c ON o.color=c.id WHERE m.nexus_ref=? ORDER BY o.id'''),
      'templates': await all('''
        SELECT t.id, t.module_ref AS moduleId, t.object_ref AS objectId, t.description,
               t.attribute_type AS attributeType, t.levelable, t.has_condition AS hasCondition,
               t.display_order AS displayOrder
        FROM classifier_template t JOIN module m ON t.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY t.id'''),
      'attributes': await all('''
        SELECT a.object_ref AS objectId, a.template_ref AS templateId,
               a.attribute_value AS value
        FROM classifier_attribute a
        JOIN classifier_object o ON a.object_ref=o.id
        JOIN module m ON o.module_ref=m.id WHERE m.nexus_ref=?'''),
    };

    // v3 Locator/Chronicler rows have module_ref set (project_id NULL) —
    // reached via the module join only, so legacy project maps and timelines
    // never leak into a snapshot.
    final locator = <String, Object?>{
      'maps': await all('''
        SELECT mp.id, mp.module_ref AS moduleId, mp.map_name AS name, c.color_code AS colorCode
        FROM map mp JOIN module m ON mp.module_ref=m.id
        LEFT JOIN use_color c ON mp.color=c.id WHERE m.nexus_ref=? ORDER BY mp.id'''),
      'areas': await all('''
        SELECT a.id, a.map_id AS mapId, a.area_name AS name, c.color_code AS colorCode
        FROM map_area a JOIN map mp ON a.map_id=mp.id JOIN module m ON mp.module_ref=m.id
        LEFT JOIN use_color c ON a.color=c.id WHERE m.nexus_ref=? ORDER BY a.id'''),
      'points': await all('''
        SELECT p.area_id AS areaId, p.point_order AS "order", p.x, p.y
        FROM map_point p JOIN map_area a ON p.area_id=a.id
        JOIN map mp ON a.map_id=mp.id JOIN module m ON mp.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY p.id'''),
    };

    final eventRows = await all('''
      SELECT e.id, e.timeline_id AS timelineId, e.event_name AS name,
             sd.day AS sDay, sd.month AS sMonth, sd.years AS sYears, sd.hour AS sHour, sd.minute AS sMinute,
             ed.day AS eDay, ed.month AS eMonth, ed.years AS eYears, ed.hour AS eHour, ed.minute AS eMinute,
             c.color_code AS colorCode, e.story
      FROM timeline_event e
      JOIN timeline t ON e.timeline_id=t.id JOIN module m ON t.module_ref=m.id
      JOIN timeline_date sd ON e.start_at=sd.id
      LEFT JOIN timeline_date ed ON e.end_at=ed.id
      LEFT JOIN use_color c ON e.color=c.id
      WHERE m.nexus_ref=? ORDER BY e.id''');

    final chronicler = <String, Object?>{
      'timelines': await all('''
        SELECT t.id, t.module_ref AS moduleId, t.line_name AS name, c.color_code AS colorCode
        FROM timeline t JOIN module m ON t.module_ref=m.id
        LEFT JOIN use_color c ON t.color=c.id WHERE m.nexus_ref=? ORDER BY t.id'''),
      'events': eventRows.map((e) => <String, Object?>{
        'id': e['id'],
        'timelineId': e['timelineId'],
        'name': e['name'],
        'startKey': dateKey({
          'day': e['sDay'], 'month': e['sMonth'], 'years': e['sYears'],
          'hour': e['sHour'], 'minute': e['sMinute'],
        }),
        'endKey': e['eDay'] == null ? null : dateKey({
          'day': e['eDay'], 'month': e['eMonth'], 'years': e['eYears'],
          'hour': e['eHour'], 'minute': e['eMinute'],
        }),
        'colorCode': e['colorCode'],
        'story': e['story'],
      }).toList(),
    };

    final dateRows = await all('''
      SELECT DISTINCT d.day, d.month, d.years, d.hour, d.minute
      FROM timeline_date d
      JOIN timeline_event e ON e.start_at=d.id OR e.end_at=d.id
      JOIN timeline t ON e.timeline_id=t.id JOIN module m ON t.module_ref=m.id
      WHERE m.nexus_ref=?''');
    final dates = dateRows.map((d) => <String, Object?>{'key': dateKey(d), ...d}).toList();

    final wanderer = <String, Object?>{
      'mapEvents': await all('''
        SELECT me.module_ref AS moduleId, me.event_ref AS eventId, me.area_ref AS areaId,
               me.label, me.x, me.y
        FROM map_event me JOIN module m ON me.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY me.id'''),
    };

    final narrator = <String, Object?>{
      'dialogues': await all('''
        SELECT d.id, d.module_ref AS moduleId, d.name, c.color_code AS colorCode,
               d.pos_x AS posX, d.pos_y AS posY
        FROM story_dialogue d JOIN module m ON d.module_ref=m.id
        LEFT JOIN use_color c ON d.color=c.id WHERE m.nexus_ref=? ORDER BY d.id'''),
      'edges': await all('''
        SELECT e.module_ref AS moduleId, e.from_ref AS fromId, e.to_ref AS toId, e.label
        FROM story_edge e JOIN module m ON e.module_ref=m.id WHERE m.nexus_ref=?'''),
      'talks': await all('''
        SELECT tk.id, tk.dialogue_ref AS dialogueId, tk.speaker, tk.talk_sentence AS sentence,
               tk.row_type AS rowType, tk.talk_order AS "order"
        FROM story_talk tk JOIN story_dialogue d ON tk.dialogue_ref=d.id
        JOIN module m ON d.module_ref=m.id WHERE m.nexus_ref=? ORDER BY tk.id'''),
      // Without these a choice would round-trip as a plain line (row_type
      // defaults to 'talk' on re-insert) and its options would be gone.
      'choiceOptions': await all('''
        SELECT o.talk_ref AS talkId, o.option_text AS text, o.effect_kind AS effectKind,
               o.effect_text AS effectText, o.jump_ref AS jumpId, o.option_order AS "order"
        FROM story_choice_option o
        JOIN story_talk tk ON o.talk_ref=tk.id JOIN story_dialogue d ON tk.dialogue_ref=d.id
        JOIN module m ON d.module_ref=m.id WHERE m.nexus_ref=? ORDER BY o.id'''),
    };

    final author = <String, Object?>{
      'chapters': await all('''
        SELECT ch.id, ch.module_ref AS moduleId, ch.name, ch.chapter_content AS content,
               ch.chapter_order AS "order"
        FROM book_chapter ch JOIN module m ON ch.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY ch.id'''),
    };

    final chatscribe = <String, Object?>{
      'sessions': await all('''
        SELECT s.id, s.module_ref AS moduleId, s.name, s.session_order AS "order",
               s.create_at AS createAt
        FROM chat_session s JOIN module m ON s.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY s.id'''),
      'messages': await all('''
        SELECT msg.session_ref AS sessionId, msg.message, msg.create_at AS createAt
        FROM chat_message msg JOIN chat_session s ON msg.session_ref=s.id
        JOIN module m ON s.module_ref=m.id WHERE m.nexus_ref=? ORDER BY msg.id'''),
    };

    final sketcher = <String, Object?>{
      'pages': await all('''
        SELECT p.id, p.module_ref AS moduleId, p.name, p.page_order AS "order"
        FROM sketch_page p JOIN module m ON p.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY p.id'''),
      'strokes': await all('''
        SELECT st.page_ref AS pageId, st.color, st.width, st.points
        FROM sketch_stroke st JOIN sketch_page p ON st.page_ref=p.id
        JOIN module m ON p.module_ref=m.id WHERE m.nexus_ref=? ORDER BY st.id'''),
      'pins': await all('''
        SELECT pn.page_ref AS pageId, pn.linker_key AS linkerKey, pn.x, pn.y
        FROM sketch_pin pn JOIN sketch_page p ON pn.page_ref=p.id
        JOIN module m ON p.module_ref=m.id WHERE m.nexus_ref=? ORDER BY pn.id'''),
    };

    final designer = <String, Object?>{
      'nodes': await all('''
        SELECT n.id, n.module_ref AS moduleId, n.shape, n.x, n.y, n.node_text AS text,
               n.color, n.linker_key AS linkerKey
        FROM design_node n JOIN module m ON n.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY n.id'''),
      'edges': await all('''
        SELECT e.module_ref AS moduleId, e.from_ref AS fromId, e.to_ref AS toId, e.label
        FROM design_edge e JOIN module m ON e.module_ref=m.id WHERE m.nexus_ref=?'''),
    };

    final relations = await allGlobal('''
      SELECT from_key AS fromKey, to_key AS toKey, label
      FROM entity_relation WHERE nexus_ref=? ORDER BY id''');

    // Nexus-scoped like relations, so allGlobal — a single module cannot carry
    // the whole vault's calendar templates.
    final calendarTemplates = await allGlobal('''
      SELECT name, spec, builtin FROM calendar_template WHERE nexus_ref=? ORDER BY id''');

    final notes = <String, Object?>{
      'folders': await allGlobal('''
        SELECT f.id, f.parent_ref AS parentId, f.name, c.color_code AS colorCode
        FROM note_folder f LEFT JOIN use_color c ON f.color=c.id
        WHERE f.nexus_ref=? ORDER BY f.id'''),
      'notes': await allGlobal('''
        SELECT n.id, n.folder_ref AS folderId, n.title, n.content,
               c.color_code AS colorCode, n.pinned
        FROM note n LEFT JOIN use_color c ON n.color=c.id
        WHERE n.nexus_ref=? ORDER BY n.id'''),
    };

    // Every colour code referenced anywhere above, deduped. Colours cross the
    // wire as CODES, never ids: `use_color.id` means nothing in the receiving
    // database (see docs/VAULTS.md §2 on why `vaultColorId()` exists).
    final colors = <String>{};
    void addColor(Object? c) {
      if (c is String && c.isNotEmpty) colors.add(c);
    }

    addColor(nexus['colorCode']);
    for (final m in modules) {
      addColor(m['iconColorCode']);
      addColor(m['colorCode']);
    }
    for (final t in moduleTags) {
      addColor(t['colorCode']);
    }
    for (final section in <List<Map<String, Object?>>>[
      classifier['objects'] as List<Map<String, Object?>>,
      locator['maps'] as List<Map<String, Object?>>,
      locator['areas'] as List<Map<String, Object?>>,
      chronicler['timelines'] as List<Map<String, Object?>>,
      narrator['dialogues'] as List<Map<String, Object?>>,
      notes['folders'] as List<Map<String, Object?>>,
      notes['notes'] as List<Map<String, Object?>>,
    ]) {
      for (final r in section) {
        addColor(r['colorCode']);
      }
    }
    for (final e in chronicler['events'] as List<Map<String, Object?>>) {
      addColor(e['colorCode']);
    }

    final hashtags = <Map<String, Object?>>[];
    final seenTags = <String>{};
    for (final t in moduleTags) {
      final name = t['tagName'];
      if (name is! String || seenTags.contains(name)) continue;
      seenTags.add(name);
      hashtags.add({'name': name, 'colorCode': t['colorCode']});
    }

    return <String, Object?>{
      'format': format,
      'version': version,
      'app': null,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'nexus': {'name': nexus['name'], 'memo': nexus['memo'], 'colorCode': nexus['colorCode']},
      'lookups': {'colors': colors.toList(), 'hashtags': hashtags, 'dates': dates},
      'modules': modules,
      'pageBlocks': pageBlocks,
      'moduleUi': moduleUi,
      'moduleTags': moduleTags,
      'classifier': classifier,
      'locator': locator,
      'chronicler': chronicler,
      'wanderer': wanderer,
      'narrator': narrator,
      'author': author,
      'chatscribe': chatscribe,
      'sketcher': sketcher,
      'designer': designer,
      'relations': relations,
      'notes': notes,
      'calendarTemplates': calendarTemplates,
    };
  }

  // ---------------------------------------------------------------------
  // Apply
  // ---------------------------------------------------------------------

  /// Whole-Nexus wipe-and-rebuild — the DDX Transfer receive path.
  ///
  /// [nexusId] must be a Nexus the caller is willing to LOSE: every module,
  /// relation, note and calendar template in it is deleted first. The receive
  /// flow creates an empty Nexus for this and never points it at one the user
  /// is working in.
  static Future<SnapshotApplyResult> applySnapshot(
      Database db, int nexusId, Object? payload) async {
    if (!validate(payload)) return SnapshotApplyResult.failed('bad_snapshot');
    final p = (payload as Map).cast<String, Object?>();

    List<Map<String, Object?>> arr(Object? v) => v is List
        ? v.whereType<Map>().map((e) => e.cast<String, Object?>()).toList()
        : <Map<String, Object?>>[];
    Map<String, Object?> sect(Object? v) =>
        v is Map ? v.cast<String, Object?>() : <String, Object?>{};

    var result = SnapshotApplyResult.failed('apply_failed');

    // PRAGMA foreign_keys is set in DatabaseHelper._onConfigure and must stay
    // OUTSIDE any transaction — inside one it is a silent no-op, which is how
    // you end up with a file full of orphans that looks fine (docs/VAULTS.md).
    await db.transaction((txn) async {
      // The wipe. `module` CASCADEs to every per-kind child, v3
      // map -> map_area -> map_point and timeline -> timeline_event included.
      await txn.rawDelete('DELETE FROM module WHERE nexus_ref=?', [nexusId]);
      await txn.rawDelete('DELETE FROM entity_relation WHERE nexus_ref=?', [nexusId]);
      await txn.rawDelete('DELETE FROM note WHERE nexus_ref=?', [nexusId]);
      await txn.rawDelete('DELETE FROM note_folder WHERE nexus_ref=?', [nexusId]);
      await txn.rawDelete('DELETE FROM wiki_link WHERE nexus_ref=?', [nexusId]);
      await txn.rawDelete('DELETE FROM calendar_template WHERE nexus_ref=?', [nexusId]);

      // --- lookups, by natural key -------------------------------------
      final lookups = sect(p['lookups']);

      final colorMap = <String, int>{};
      final colorList = lookups['colors'];
      for (final code in (colorList is List ? colorList : const <Object?>[])) {
        if (code is! String || code.isEmpty) continue;
        await txn.rawInsert('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
        final row = await txn.rawQuery('SELECT id FROM use_color WHERE color_code=?', [code]);
        if (row.isNotEmpty) colorMap[code] = row.first['id']! as int;
      }
      int? colorId(Object? code) => code is String ? colorMap[code] : null;

      final tagMap = <String, int>{};
      for (final tg in arr(lookups['hashtags'])) {
        final name = tg['name'];
        if (name is! String || name.isEmpty) continue;
        await txn.rawInsert('INSERT OR IGNORE INTO hashtag (tag_name, tag_color) VALUES (?,?)',
            [name, colorId(tg['colorCode'])]);
        final row = await txn.rawQuery('SELECT id FROM hashtag WHERE tag_name=?', [name]);
        if (row.isNotEmpty) tagMap[name] = row.first['id']! as int;
      }

      final dateMap = <String, int>{};
      for (final d in arr(lookups['dates'])) {
        final args = <Object?>[d['day'], d['month'], d['years'], d['hour'], d['minute']];
        await txn.rawInsert(
            'INSERT OR IGNORE INTO timeline_date (day,month,years,hour,minute) VALUES (?,?,?,?,?)', args);
        final row = await txn.rawQuery(
            'SELECT id FROM timeline_date WHERE day=? AND month=? AND years=? AND hour=? AND minute=?', args);
        final key = d['key'];
        if (row.isNotEmpty && key is String) dateMap[key] = row.first['id']! as int;
      }

      // The local Nexus NAME is kept: it is UNIQUE per install, and the
      // sender's name is display information, not an identity to adopt.
      final nexusMeta = sect(p['nexus']);
      await txn.rawUpdate(
          "UPDATE nexus SET memo=?, color=?, update_at=datetime('now') WHERE id=?",
          [nexusMeta['memo'], colorId(nexusMeta['colorCode']), nexusId]);

      // --- modules, parents first --------------------------------------
      // BFS rather than the snapshot's own order, so a child can never land
      // before the parent it points at.
      final modMap = <int, int>{};
      var pending = arr(p['modules']);
      while (pending.isNotEmpty) {
        final next = <Map<String, Object?>>[];
        var progressed = false;
        for (final m in pending) {
          final oldParent = m['parentId'];
          if (oldParent is int && !modMap.containsKey(oldParent)) {
            next.add(m);
            continue;
          }
          final parentId = oldParent is int ? modMap[oldParent] : null;

          // A handle is unique per Nexus and this one may already be taken.
          // Dropping the clash to NULL keeps the module importable; throwing
          // would abort the whole transaction over a cosmetic field, and
          // renaming it would invent a handle the user never chose.
          Object? handle = m['handle'];
          if (handle != null) {
            final clash = await txn.rawQuery(
                'SELECT id FROM module WHERE nexus_ref=? AND handle=? COLLATE NOCASE',
                [nexusId, handle]);
            if (clash.isNotEmpty) handle = null;
          }

          final id = await txn.rawInsert(
            'INSERT INTO module (nexus_ref, parent_id, name, kind, icon, icon_color, color, '
            'description, display_order, pinned, cat_type, handle, create_at, update_at) '
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,COALESCE(?,datetime('now')),COALESCE(?,datetime('now')))",
            <Object?>[
              nexusId, parentId, m['name'], m['kind'], m['icon'],
              colorId(m['iconColorCode']), colorId(m['colorCode']),
              m['description'], m['displayOrder'] ?? 0, m['pinned'] ?? 0,
              m['catType'], handle, m['createAt'], m['updateAt'],
            ],
          );
          final oldId = m['id'];
          if (oldId is int) modMap[oldId] = id;
          progressed = true;
        }
        if (!progressed) break; // orphaned parentIds — drop the remainder
        pending = next;
      }
      int? mod(Object? oldId) => oldId is int ? modMap[oldId] : null;

      // --- per-kind children, in dependency order -----------------------
      // A v1 snapshot's module attributes are property blocks now (§12).
      for (final a in arr(p['moduleAttrs'])) {
        final m = mod(a['moduleId']);
        if (m == null) continue;
        await txn.rawInsert(
            "INSERT INTO page_block (module_ref, block_type, prop_name, prop_type, content, block_order) "
            "VALUES (?,'property',?,'text',?,?)",
            <Object?>[m, a['name'], a['value'], a['displayOrder'] ?? 0]);
      }
      for (final tg in arr(p['moduleTags'])) {
        final m = mod(tg['moduleId']);
        final tagId = tagMap[tg['tagName']];
        if (m == null || tagId == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO module_hashtag (module_ref, hashtag_id) VALUES (?,?)',
            <Object?>[m, tagId]);
      }

      final cls = sect(p['classifier']);
      final cobjMap = <int, int>{};
      for (final o in arr(cls['objects'])) {
        final m = mod(o['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO classifier_object (module_ref, name, color, note, display_order) VALUES (?,?,?,?,?)',
            <Object?>[m, o['name'], colorId(o['colorCode']), o['note'], o['displayOrder'] ?? 0]);
        final oldId = o['id'];
        if (oldId is int) cobjMap[oldId] = id;
      }
      final ctplMap = <int, int>{};
      for (final t in arr(cls['templates'])) {
        final m = mod(t['moduleId']);
        if (m == null) continue;
        final objectId = t['objectId'];
        if (objectId is int && !cobjMap.containsKey(objectId)) continue;
        final id = await txn.rawInsert(
            'INSERT INTO classifier_template (module_ref, object_ref, description, attribute_type, '
            'levelable, has_condition, display_order) VALUES (?,?,?,?,?,?,?)',
            <Object?>[
              m, objectId is int ? cobjMap[objectId] : null, t['description'],
              t['attributeType'] ?? 'text', t['levelable'] ?? 0, t['hasCondition'] ?? 0,
              t['displayOrder'] ?? 0,
            ]);
        final oldId = t['id'];
        if (oldId is int) ctplMap[oldId] = id;
      }
      for (final a in arr(cls['attributes'])) {
        final obj = cobjMap[a['objectId']];
        final tpl = ctplMap[a['templateId']];
        if (obj == null || tpl == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO classifier_attribute (object_ref, template_ref, attribute_value) VALUES (?,?,?)',
            <Object?>[obj, tpl, a['value']]);
      }

      final loc = sect(p['locator']);
      final mapMap = <int, int>{};
      for (final r in arr(loc['maps'])) {
        final m = mod(r['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO map (map_name, module_ref, color) VALUES (?,?,?)',
            <Object?>[r['name'], m, colorId(r['colorCode'])]);
        final oldId = r['id'];
        if (oldId is int) mapMap[oldId] = id;
      }
      final areaMap = <int, int>{};
      for (final r in arr(loc['areas'])) {
        final mapId = mapMap[r['mapId']];
        if (mapId == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO map_area (map_id, area_name, color) VALUES (?,?,?)',
            <Object?>[mapId, r['name'], colorId(r['colorCode'])]);
        final oldId = r['id'];
        if (oldId is int) areaMap[oldId] = id;
      }
      for (final pt in arr(loc['points'])) {
        final areaId = areaMap[pt['areaId']];
        if (areaId == null) continue;
        await txn.rawInsert('INSERT INTO map_point (area_id, point_order, x, y) VALUES (?,?,?,?)',
            <Object?>[areaId, pt['order'] ?? 0, pt['x'], pt['y']]);
      }

      final chr = sect(p['chronicler']);
      final tlMap = <int, int>{};
      for (final t in arr(chr['timelines'])) {
        final m = mod(t['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO timeline (line_name, module_ref, color) VALUES (?,?,?)',
            <Object?>[t['name'], m, colorId(t['colorCode'])]);
        final oldId = t['id'];
        if (oldId is int) tlMap[oldId] = id;
      }
      final evtMap = <int, int>{};
      for (final e in arr(chr['events'])) {
        final tl = tlMap[e['timelineId']];
        final startAt = dateMap[e['startKey']];
        if (tl == null || startAt == null) continue;
        final endKey = e['endKey'];
        final id = await txn.rawInsert(
            'INSERT INTO timeline_event (timeline_id, event_name, start_at, end_at, color, story) '
            'VALUES (?,?,?,?,?,?)',
            <Object?>[
              tl, e['name'], startAt, endKey is String ? dateMap[endKey] : null,
              colorId(e['colorCode']), e['story'],
            ]);
        final oldId = e['id'];
        if (oldId is int) evtMap[oldId] = id;
      }

      for (final me in arr(sect(p['wanderer'])['mapEvents'])) {
        final m = mod(me['moduleId']);
        if (m == null) continue;
        await txn.rawInsert(
            'INSERT INTO map_event (module_ref, event_ref, area_ref, label, x, y) VALUES (?,?,?,?,?,?)',
            <Object?>[m, evtMap[me['eventId']], areaMap[me['areaId']], me['label'],
                      me['x'] ?? 0, me['y'] ?? 0]);
      }

      final nar = sect(p['narrator']);
      final dlgMap = <int, int>{};
      for (final d in arr(nar['dialogues'])) {
        final m = mod(d['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO story_dialogue (module_ref, name, color, pos_x, pos_y) VALUES (?,?,?,?,?)',
            <Object?>[m, d['name'], colorId(d['colorCode']), d['posX'] ?? 0, d['posY'] ?? 0]);
        final oldId = d['id'];
        if (oldId is int) dlgMap[oldId] = id;
      }
      for (final e in arr(nar['edges'])) {
        final m = mod(e['moduleId']);
        final from = dlgMap[e['fromId']];
        final to = dlgMap[e['toId']];
        if (m == null || from == null || to == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO story_edge (module_ref, from_ref, to_ref, label) VALUES (?,?,?,?)',
            <Object?>[m, from, to, e['label']]);
      }
      final talkMap = <int, int>{};
      for (final tk in arr(nar['talks'])) {
        final dlg = dlgMap[tk['dialogueId']];
        if (dlg == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO story_talk (dialogue_ref, speaker, talk_sentence, row_type, talk_order) VALUES (?,?,?,?,?)',
            <Object?>[dlg, tk['speaker'], tk['sentence'],
                      tk['rowType'] == 'choice' ? 'choice' : 'talk', tk['order'] ?? 0]);
        final oldId = tk['id'];
        if (oldId is int) talkMap[oldId] = id;
      }
      for (final op in arr(nar['choiceOptions'])) {
        final talk = talkMap[op['talkId']];
        if (talk == null) continue;
        final jump = op['jumpId'];
        await txn.rawInsert(
            'INSERT INTO story_choice_option (talk_ref, option_text, effect_kind, effect_text, jump_ref, option_order) '
            'VALUES (?,?,?,?,?,?)',
            <Object?>[talk, op['text'], op['effectKind'] ?? 'none', op['effectText'],
                      jump is int ? dlgMap[jump] : null, op['order'] ?? 0]);
      }

      final bchpMap = <int, int>{};
      for (final ch in arr(sect(p['author'])['chapters'])) {
        final m = mod(ch['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO book_chapter (module_ref, name, chapter_content, chapter_order) VALUES (?,?,?,?)',
            <Object?>[m, ch['name'], ch['content'], ch['order'] ?? 0]);
        final oldId = ch['id'];
        if (oldId is int) bchpMap[oldId] = id;
      }

      final cht = sect(p['chatscribe']);
      final chssMap = <int, int>{};
      for (final s in arr(cht['sessions'])) {
        final m = mod(s['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO chat_session (module_ref, name, session_order, create_at) '
            "VALUES (?,?,?,COALESCE(?,datetime('now')))",
            <Object?>[m, s['name'], s['order'] ?? 0, s['createAt']]);
        final oldId = s['id'];
        if (oldId is int) chssMap[oldId] = id;
      }
      for (final msg in arr(cht['messages'])) {
        final ses = chssMap[msg['sessionId']];
        if (ses == null) continue;
        await txn.rawInsert(
            "INSERT INTO chat_message (session_ref, message, create_at) VALUES (?,?,COALESCE(?,datetime('now')))",
            <Object?>[ses, msg['message'], msg['createAt']]);
      }

      final skt = sect(p['sketcher']);
      final pageMap = <int, int>{};
      for (final pg in arr(skt['pages'])) {
        final m = mod(pg['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO sketch_page (module_ref, name, page_order) VALUES (?,?,?)',
            <Object?>[m, pg['name'], pg['order'] ?? 0]);
        final oldId = pg['id'];
        if (oldId is int) pageMap[oldId] = id;
      }
      for (final st in arr(skt['strokes'])) {
        final page = pageMap[st['pageId']];
        if (page == null) continue;
        await txn.rawInsert('INSERT INTO sketch_stroke (page_ref, color, width, points) VALUES (?,?,?,?)',
            <Object?>[page, st['color'], st['width'] ?? 3, st['points']]);
      }

      // Every id map a linker key can point at. Built here because sketch pins
      // and design nodes are the first rows that have to resolve one.
      //
      // tlev/sdlg (APP docs/V5.md §11.1): both maps existed above but were
      // never registered, so every pull dropped relations, sketch pins and
      // Designer links that pointed at an event or a dialogue — the same bug
      // EXE had, copied from its importer. EXE now derives this list from
      // one registry (db/entity-kinds.js); this side follows in APK V3.
      final keyMaps = <String, Map<int, int>>{
        'module': modMap, 'cobj': cobjMap, 'bchp': bchpMap, 'chss': chssMap,
        'tlev': evtMap, 'sdlg': dlgMap, 'skpg': pageMap, 'ctpl': ctplMap,
      };

      var droppedPins = 0;
      for (final pn in arr(skt['pins'])) {
        final page = pageMap[pn['pageId']];
        if (page == null) continue;
        final k = remapEntityKey(pn['linkerKey'], keyMaps);
        // linker_key is NOT NULL, so an unmappable pin has to be dropped
        // rather than inserted with a dangling key.
        if (k == null) {
          droppedPins++;
          continue;
        }
        await txn.rawInsert('INSERT INTO sketch_pin (page_ref, linker_key, x, y) VALUES (?,?,?,?)',
            <Object?>[page, k, pn['x'] ?? 0, pn['y'] ?? 0]);
      }

      final dsg = sect(p['designer']);
      final dnodeMap = <int, int>{};
      for (final n in arr(dsg['nodes'])) {
        final m = mod(n['moduleId']);
        if (m == null) continue;
        final k = n['linkerKey'] == null ? null : remapEntityKey(n['linkerKey'], keyMaps);
        final id = await txn.rawInsert(
            'INSERT INTO design_node (module_ref, shape, x, y, node_text, color, linker_key) '
            'VALUES (?,?,?,?,?,?,?)',
            <Object?>[m, n['shape'] ?? 'box', n['x'] ?? 0, n['y'] ?? 0,
                      n['text'], n['color'], k]);
        final oldId = n['id'];
        if (oldId is int) dnodeMap[oldId] = id;
      }
      for (final e in arr(dsg['edges'])) {
        final m = mod(e['moduleId']);
        final from = dnodeMap[e['fromId']];
        final to = dnodeMap[e['toId']];
        if (m == null || from == null || to == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO design_edge (module_ref, from_ref, to_ref, label) VALUES (?,?,?,?)',
            <Object?>[m, from, to, e['label']]);
      }

      // --- notes (folder tree parents-first), then relations -------------
      final nts = sect(p['notes']);
      final nfMap = <int, int>{};
      var pendingF = arr(nts['folders']);
      while (pendingF.isNotEmpty) {
        final next = <Map<String, Object?>>[];
        var progressed = false;
        for (final f in pendingF) {
          final oldParent = f['parentId'];
          if (oldParent is int && !nfMap.containsKey(oldParent)) {
            next.add(f);
            continue;
          }
          final id = await txn.rawInsert(
              'INSERT INTO note_folder (nexus_ref, parent_ref, name, color) VALUES (?,?,?,?)',
              <Object?>[nexusId, oldParent is int ? nfMap[oldParent] : null,
                        f['name'], colorId(f['colorCode'])]);
          final oldId = f['id'];
          if (oldId is int) nfMap[oldId] = id;
          progressed = true;
        }
        if (!progressed) break;
        pendingF = next;
      }

      final noteMap = <int, int>{};
      for (final n in arr(nts['notes'])) {
        final folderId = n['folderId'];
        final id = await txn.rawInsert(
            'INSERT OR IGNORE INTO note (nexus_ref, folder_ref, title, content, color, pinned) '
            'VALUES (?,?,?,?,?,?)',
            <Object?>[nexusId, folderId is int ? nfMap[folderId] : null, n['title'],
                      n['content'] ?? '', colorId(n['colorCode']), n['pinned'] ?? 0]);
        // OR IGNORE reports 0 when the row was skipped (a title collision).
        // Leaving it out of the map is what stops a relation pointing at a
        // note that was never inserted.
        final oldId = n['id'];
        if (id != 0 && oldId is int) noteMap[oldId] = id;
      }
      // note_<id> relation endpoints resolve through this too, so it joins the
      // key maps only once the notes actually exist.
      keyMaps['note'] = noteMap;

      // Page blocks: item_key / source_key are entity keys, so they wait for
      // every map. '*' (the shared element layout) is not a key and stays.
      // Parents first, the same BFS as modules.
      final blockMap = <int, int>{};
      var pendingBlocks = arr(p['pageBlocks']);
      while (pendingBlocks.isNotEmpty) {
        final next = <Map<String, Object?>>[];
        var progressed = false;
        for (final b in pendingBlocks) {
          final m = mod(b['moduleId']);
          if (m == null) continue;
          final oldParent = b['parentId'];
          if (oldParent is int && !blockMap.containsKey(oldParent)) {
            next.add(b);
            continue;
          }
          final item = b['itemKey'];
          final itemKey = item == null || item == '*' ? item : remapEntityKey(item, keyMaps);
          if (item != null && itemKey == null) continue; // its element did not come along
          final id = await txn.rawInsert(
            'INSERT INTO page_block (module_ref, item_key, parent_id, block_type, component, source_key, '
            'config, content, prop_name, prop_type, block_order) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
            <Object?>[
              m, itemKey, oldParent is int ? blockMap[oldParent] : null,
              b['type'] ?? 'component', b['component'], remapEntityKey(b['sourceKey'], keyMaps),
              b['config'], b['content'], b['propName'], b['propType'], b['order'] ?? 0,
            ],
          );
          final oldId = b['id'];
          if (oldId is int) blockMap[oldId] = id;
          progressed = true;
        }
        if (!progressed) break;
        pendingBlocks = next;
      }

      var droppedRelations = 0;
      for (final rel in arr(p['relations'])) {
        final fk = remapEntityKey(rel['fromKey'], keyMaps);
        final tk = remapEntityKey(rel['toKey'], keyMaps);
        if (fk == null || tk == null) {
          droppedRelations++;
          continue;
        }
        await txn.rawInsert(
            'INSERT OR IGNORE INTO entity_relation (nexus_ref, from_key, to_key, label) VALUES (?,?,?,?)',
            <Object?>[nexusId, fk, tk, rel['label']]);
      }

      // Templates carry no entity ids, so unlike relations they need no remap.
      // A name collision keeps the target's own copy rather than overwriting a
      // calendar the user may already be using.
      for (final ct in arr(p['calendarTemplates'])) {
        if (ct['name'] == null || ct['spec'] == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO calendar_template (nexus_ref, name, spec, builtin) VALUES (?,?,?,?)',
            <Object?>[nexusId, ct['name'], ct['spec'],
                      (ct['builtin'] == 1 || ct['builtin'] == true) ? 1 : 0]);
      }

      // module_ui LAST: Wanderer's mapModule/timelineModule values are module
      // ids and have to go through modMap. Every other ui value is copied
      // verbatim — an entity id embedded in one (a Viewer filter definition,
      // say) stays stale, which is a documented limitation of the format on
      // both sides, not a difference between them.
      for (final u in arr(p['moduleUi'])) {
        final m = mod(u['moduleId']);
        if (m == null) continue;
        Object? value = u['value'];
        if (u['key'] == 'mapModule' || u['key'] == 'timelineModule') {
          final target = modMap[int.tryParse('${u['value']}')];
          if (target == null) continue;
          value = '$target';
        }
        await txn.rawInsert(
            'INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,?)',
            <Object?>[m, u['key'], value]);
      }

      result = SnapshotApplyResult(
        ok: true,
        modules: modMap.length,
        notes: noteMap.length,
        relations: arr(p['relations']).length - droppedRelations,
        droppedRelations: droppedRelations,
        droppedPins: droppedPins,
      );
    });

    return result;
  }

  /// `"module_12"` -> `"module_57"` through the per-kind maps; null when it
  /// cannot be mapped (a legacy kind, or a row this snapshot no longer holds).
  static String? remapEntityKey(Object? key, Map<String, Map<int, int>> maps) {
    final m = RegExp(r'^([a-z]+)_(\d+)$').firstMatch('${key ?? ''}');
    if (m == null) return null;
    final map = maps[m.group(1)];
    if (map == null) return null;
    final mapped = map[int.parse(m.group(2)!)];
    return mapped == null ? null : '${m.group(1)}_$mapped';
  }

  /// "This module and every descendant", walked in memory rather than with a
  /// recursive CTE — same reason as the JS: it must not depend on the SQLite
  /// build supporting `WITH RECURSIVE`.
  static Future<List<int>> collectModuleSubtreeIds(
      DatabaseExecutor db, int nexusId, int moduleId) async {
    final rows = await db.rawQuery(
        'SELECT id, parent_id AS parentId FROM module WHERE nexus_ref=?', [nexusId]);
    final children = <int, List<int>>{};
    for (final r in rows) {
      final parent = r['parentId'];
      if (parent is int) (children[parent] ??= <int>[]).add(r['id'] as int);
    }
    final out = <int>[];
    final stack = <int>[moduleId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      out.add(id);
      stack.addAll(children[id] ?? const <int>[]);
    }
    return out;
  }
}


/// What [VaultSnapshotService.applySnapshot] managed to bring in. The dropped
/// counts are not errors: a relation whose endpoint is a kind this snapshot
/// never carried, or a sketch pin pointing at a row that is gone, has nowhere
/// to land, and is reported rather than silently lost.
class SnapshotApplyResult {
  const SnapshotApplyResult({
    required this.ok,
    this.code,
    this.modules = 0,
    this.notes = 0,
    this.relations = 0,
    this.droppedRelations = 0,
    this.droppedPins = 0,
  });

  factory SnapshotApplyResult.failed(String code) => SnapshotApplyResult(ok: false, code: code);

  final bool ok;
  final String? code;
  final int modules;
  final int notes;
  final int relations;
  final int droppedRelations;
  final int droppedPins;
}
