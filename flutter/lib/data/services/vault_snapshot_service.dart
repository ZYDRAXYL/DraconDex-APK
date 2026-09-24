import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/module_parents.dart';
import '../../core/entity/entity_kinds.dart';
import '../models/module_model.dart';
import 'wiki_service.dart';

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
    String? appVersion,
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
               t.display_order AS displayOrder, t.options
        FROM classifier_template t JOIN module m ON t.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY t.id'''),
      'attributes': await all('''
        SELECT a.object_ref AS objectId, a.template_ref AS templateId,
               a.attribute_value AS value
        FROM classifier_attribute a
        JOIN classifier_object o ON a.object_ref=o.id
        JOIN module m ON o.module_ref=m.id WHERE m.nexus_ref=?'''),
      // A levelled / conditioned field's value is its rows (EXE sync.js
      // classifier.levels). A missing key reads as none, so older snapshots
      // import unchanged.
      'levels': await all('''
        SELECT l.object_ref AS objectId, l.template_ref AS templateId,
               l.level_label AS levelLabel, l.condition_value AS conditionValue,
               l.info_value AS infoValue, l.display_order AS displayOrder
        FROM classifier_level l
        JOIN classifier_object o ON l.object_ref=o.id
        JOIN module m ON o.module_ref=m.id WHERE m.nexus_ref=? ORDER BY l.display_order, l.id'''),
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
    // Growable: a time-bound relation adds the dates of its span below.
    final dates = dateRows.map((d) => <String, Object?>{'key': dateKey(d), ...d}).toList();

    final wanderer = <String, Object?>{
      'mapEvents': await all('''
        SELECT me.id, me.module_ref AS moduleId, me.event_ref AS eventId, me.area_ref AS areaId,
               me.label, me.linker_key AS linkerKey, me.x, me.y
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
               o.effect_text AS effectText, o.jump_ref AS jumpId, o.option_order AS "order",
               o.condition, o.set_ops AS setOps
        FROM story_choice_option o
        JOIN story_talk tk ON o.talk_ref=tk.id JOIN story_dialogue d ON tk.dialogue_ref=d.id
        JOIN module m ON d.module_ref=m.id WHERE m.nexus_ref=? ORDER BY o.id'''),
    };

    final author = <String, Object?>{
      'chapters': await all('''
        SELECT ch.id, ch.module_ref AS moduleId, ch.name, ch.chapter_content AS content,
               ch.chapter_order AS "order", ch.synopsis, ch.status, ch.pov_key AS povKey
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
               n.color, n.linker_key AS linkerKey, n.w, n.h, n.read_order AS readOrder
        FROM design_node n JOIN module m ON n.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY n.id'''),
      'edges': await all('''
        SELECT e.module_ref AS moduleId, e.from_ref AS fromId, e.to_ref AS toId, e.label
        FROM design_edge e JOIN module m ON e.module_ref=m.id WHERE m.nexus_ref=?'''),
    };

    // v5 Part 7 (§11.5): Diviner tables, their entries and roll history. An
    // entry's linker_key (divt_<id> = roll that table) is a key like any other.
    final diviner = <String, Object?>{
      'tables': await all('''
        SELECT t.id, t.module_ref AS moduleId, t.name, t.dice, t.mode, t.display_order AS "order"
        FROM diviner_table t JOIN module m ON t.module_ref=m.id WHERE m.nexus_ref=? ORDER BY t.id'''),
      'entries': await all('''
        SELECT e.id, e.table_ref AS tableId, e.weight, e.range_lo AS lo, e.range_hi AS hi,
               e.entry_text AS text, e.linker_key AS linkerKey, e.display_order AS "order"
        FROM diviner_entry e JOIN diviner_table t ON e.table_ref=t.id
        JOIN module m ON t.module_ref=m.id WHERE m.nexus_ref=? ORDER BY e.id'''),
      'rolls': await all('''
        SELECT r.table_ref AS tableId, r.dice_result AS dice, r.entry_ref AS entryId,
               r.result_text AS text, r.create_at AS createAt
        FROM diviner_roll r JOIN diviner_table t ON r.table_ref=t.id
        JOIN module m ON t.module_ref=m.id WHERE m.nexus_ref=? ORDER BY r.id'''),
    };

    // v5 (APP docs/V5.md §3.5): rel_type / directed / moduleRef travel with
    // the relation. A time-bound relation (§11.6) carries its span as date
    // KEYS — the same lookups.dates the events use — never row ids.
    final relationRows = await allGlobal('''
      SELECT r.from_key AS fromKey, r.to_key AS toKey, r.label,
             r.rel_type AS relType, r.directed, r.module_ref AS moduleId,
             f.day AS fDay, f.month AS fMonth, f.years AS fYears, f.hour AS fHour, f.minute AS fMinute,
             u.day AS uDay, u.month AS uMonth, u.years AS uYears, u.hour AS uHour, u.minute AS uMinute
      FROM entity_relation r
      LEFT JOIN timeline_date f ON r.valid_from=f.id LEFT JOIN timeline_date u ON r.valid_to=u.id
      WHERE r.nexus_ref=? ORDER BY r.id''');
    final relations = <Map<String, Object?>>[];
    for (final r in relationRows) {
      Map<String, Object?>? span(String p) => r['${p}Years'] == null
          ? null
          : {
              'day': r['${p}Day'], 'month': r['${p}Month'], 'years': r['${p}Years'],
              'hour': r['${p}Hour'], 'minute': r['${p}Minute'],
            };
      final from = span('f');
      final to = span('u');
      for (final d in [from, to]) {
        if (d != null && !dates.any((x) => x['key'] == dateKey(d))) dates.add({'key': dateKey(d), ...d});
      }
      relations.add({
        'fromKey': r['fromKey'], 'toKey': r['toKey'], 'label': r['label'],
        'relType': r['relType'], 'directed': r['directed'], 'moduleId': r['moduleId'],
        'validFrom': from == null ? null : dateKey(from),
        'validTo': to == null ? null : dateKey(to),
      });
    }

    // v5 Exhibitor scenes, module-scoped like designer.
    final exhibitor = <String, Object?>{
      'nodes': await all('''
        SELECT n.id, n.module_ref AS moduleId, n.parent_id AS parentId, n.node_type AS nodeType,
               n.linker_key AS linkerKey, n.label, n.x, n.y, n.w, n.h, n.z, n.rotation, n.scale,
               n.locked, n.hidden, n.color, n.props
        FROM exhibit_node n JOIN module m ON n.module_ref=m.id
        WHERE m.nexus_ref=? ORDER BY n.id'''),
      'views': await all('''
        SELECT v.module_ref AS moduleId, v.scale, v.tx, v.ty, v.bg_linker_key AS bgLinkerKey, v.grid, v.snap
        FROM exhibit_view v JOIN module m ON v.module_ref=m.id WHERE m.nexus_ref=?'''),
    };

    // Nexus-scoped like relations, so allGlobal — a single module cannot carry
    // the whole vault's calendar templates.
    final calendarTemplates = await allGlobal('''
      SELECT name, spec, builtin FROM calendar_template WHERE nexus_ref=? ORDER BY id''');
    // v5 Part 6 (§10.8): the user's module presets — nexus-scoped the same way.
    final modulePresets = await allGlobal('''
      SELECT kind, name, spec FROM module_preset WHERE nexus_ref=? ORDER BY id''');

    final notes = <String, Object?>{
      'folders': await allGlobal('''
        SELECT f.id, f.parent_ref AS parentId, f.name, c.color_code AS colorCode
        FROM note_folder f LEFT JOIN use_color c ON f.color=c.id
        WHERE f.nexus_ref=? ORDER BY f.id'''),
      'notes': await allGlobal('''
        SELECT n.id, n.folder_ref AS folderId, n.title, n.content,
               c.color_code AS colorCode, n.pinned
        FROM note n LEFT JOIN use_color c ON n.color=c.id
        WHERE n.nexus_ref=? AND n.migrated_v3=0 ORDER BY n.id'''),
      // ↑ A converted note is a module now (the desktop's autoMigrateNotes)
      //   and travels as one. Sending the note too would have the receiver
      //   convert it a second time, into a duplicate module.
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
      'app': appVersion,
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
      'exhibitor': exhibitor,
      'modulePresets': modulePresets,
      'diviner': diviner,
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
  static Future<SnapshotApplyResult> applySnapshot(Database db, int nexusId, Object? payload) =>
      applySnapshotCore(db, nexusId, payload, wipe: true, updateNexusMeta: true);

  /// Module-subtree merge-in — a `.mddx` import, a trash restore. Additive:
  /// never wipes the target Nexus, and the snapshot's root module(s) land
  /// under [parentModuleId] (top level when null).
  static Future<SnapshotApplyResult> importModuleSnapshot(
    Database db,
    int nexusId,
    int? parentModuleId,
    Object? payload,
  ) =>
      applySnapshotCore(db, nexusId, payload, reparentRootTo: parentModuleId);

  /// The shared core of both — a transliteration of EXE `applySnapshotCore`
  /// (db/sync.js), including its insert order, which is a dependency order.
  /// Three things differ between callers:
  ///   [wipe]            clear the Nexus's synced content first
  ///   [updateNexusMeta] overwrite the Nexus row's memo/colour
  ///   [reparentRootTo]  where a module whose parent is not in the payload
  ///                     lands (null = top level)
  /// The result carries the key maps it built — the trash restores saved
  /// relations through them.
  static Future<SnapshotApplyResult> applySnapshotCore(
    Database db,
    int nexusId,
    Object? payload, {
    bool wipe = false,
    bool updateNexusMeta = false,
    int? reparentRootTo,
  }) async {
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
      if (wipe) {
        // module CASCADEs to every per-kind child, v3 map -> map_area ->
        // map_point and timeline -> timeline_event included.
        for (final t in const [
          'module', 'entity_relation', 'note', 'note_folder', 'wiki_link', 'calendar_template', 'module_preset',
        ]) {
          await txn.rawDelete('DELETE FROM $t WHERE nexus_ref=?', [nexusId]);
        }
      }

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
      if (updateNexusMeta) {
        final nexusMeta = sect(p['nexus']);
        await txn.rawUpdate(
            "UPDATE nexus SET memo=?, color=?, update_at=datetime('now') WHERE id=?",
            [nexusMeta['memo'], colorId(nexusMeta['colorCode']), nexusId]);
      }

      // --- modules, parents first --------------------------------------
      // A subtree's root still names its old parent, which is not in the
      // payload (a .mddx of a nested module, a trashed module) — so a root
      // is "no parent, or a parent that is not here", and it lands where
      // the caller says.
      final modMap = <int, int>{};
      final legacyKind = <int, String>{}; // old id -> 'viewer'|'connector'
      final allModules = arr(p['modules']);
      final inPayload = {for (final m in allModules) m['id']};
      bool isRoot(Map<String, Object?> m) => m['parentId'] == null || !inPayload.contains(m['parentId']);
      var pending = allModules;
      while (pending.isNotEmpty) {
        final next = <Map<String, Object?>>[];
        var progressed = false;
        for (final m in pending) {
          if (!isRoot(m) && !modMap.containsKey(m['parentId'])) {
            next.add(m);
            continue;
          }
          final parentId = isRoot(m) ? reparentRootTo : modMap[m['parentId']];

          // A handle is unique per Nexus and this one may already be taken.
          // Dropping the clash to NULL keeps the module importable; throwing
          // would abort the whole transaction over a cosmetic field, and
          // renaming it would invent a handle the user never chose.
          Object? handle = m['handle'];
          if (handle != null) {
            final clash = await txn.rawQuery(
                'SELECT id FROM module WHERE nexus_ref=? AND handle=? COLLATE NOCASE', [nexusId, handle]);
            if (clash.isNotEmpty) handle = null;
          }
          final kind = '${m['kind']}';
          final legacy = ModuleKind.legacyIds[kind]?.id;
          final id = await txn.rawInsert(
            'INSERT INTO module (nexus_ref, parent_id, name, kind, icon, icon_color, color, '
            'description, display_order, pinned, cat_type, handle, create_at, update_at) '
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,COALESCE(?,datetime('now')),COALESCE(?,datetime('now')))",
            <Object?>[
              nexusId, parentId, m['name'], legacy ?? kind, m['icon'],
              colorId(m['iconColorCode']), colorId(m['colorCode']),
              m['description'], m['displayOrder'] ?? 0, m['pinned'] ?? 0,
              m['catType'], handle, m['createAt'], m['updateAt'],
            ],
          );
          final oldId = m['id'];
          if (oldId is int) {
            modMap[oldId] = id;
            if (legacy != null) legacyKind[oldId] = kind;
          }
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
        await txn.rawInsert('INSERT OR IGNORE INTO module_hashtag (module_ref, hashtag_id) VALUES (?,?)',
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
            'levelable, has_condition, display_order, options) VALUES (?,?,?,?,?,?,?,?)',
            <Object?>[
              m, objectId is int ? cobjMap[objectId] : null, t['description'],
              t['attributeType'] ?? 'text', t['levelable'] ?? 0, t['hasCondition'] ?? 0,
              t['displayOrder'] ?? 0, t['options'],
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
      for (final l in arr(cls['levels'])) {
        final obj = cobjMap[l['objectId']];
        final tpl = ctplMap[l['templateId']];
        if (obj == null || tpl == null) continue;
        await txn.rawInsert(
            'INSERT INTO classifier_level (object_ref, template_ref, level_label, condition_value, info_value, display_order) '
            'VALUES (?,?,?,?,?,?)',
            <Object?>[obj, tpl, l['levelLabel'], l['conditionValue'], l['infoValue'], l['displayOrder'] ?? 0]);
      }

      final loc = sect(p['locator']);
      final mapMap = <int, int>{};
      for (final r in arr(loc['maps'])) {
        final m = mod(r['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert('INSERT INTO map (map_name, module_ref, color) VALUES (?,?,?)',
            <Object?>[r['name'], m, colorId(r['colorCode'])]);
        final oldId = r['id'];
        if (oldId is int) mapMap[oldId] = id;
      }
      final areaMap = <int, int>{};
      for (final r in arr(loc['areas'])) {
        final mapId = mapMap[r['mapId']];
        if (mapId == null) continue;
        final id = await txn.rawInsert('INSERT INTO map_area (map_id, area_name, color) VALUES (?,?,?)',
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
        final id = await txn.rawInsert('INSERT INTO timeline (line_name, module_ref, color) VALUES (?,?,?)',
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

      // A pin is an entity (mevt_, SDB 2.0.3) and its linker_key points at
      // any element — remapped with the other key columns below. Before,
      // neither travelled and a synced pin lost its link (EXE sync.js).
      final mevtMap = <int, int>{};
      final pinLinks = <(String, String, int, String)>[];
      for (final me in arr(sect(p['wanderer'])['mapEvents'])) {
        final m = mod(me['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO map_event (module_ref, event_ref, area_ref, label, x, y) VALUES (?,?,?,?,?,?)',
            <Object?>[m, evtMap[me['eventId']], areaMap[me['areaId']], me['label'], me['x'] ?? 0, me['y'] ?? 0]);
        final oldId = me['id'];
        if (oldId is int) mevtMap[oldId] = id;
        final lk = me['linkerKey'];
        if (lk is String && lk.isNotEmpty) pinLinks.add(('map_event', 'linker_key', id, lk));
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
            <Object?>[dlg, tk['speaker'], tk['sentence'], tk['rowType'] == 'choice' ? 'choice' : 'talk', tk['order'] ?? 0]);
        final oldId = tk['id'];
        if (oldId is int) talkMap[oldId] = id;
      }
      // condition / set_ops hold entity keys (§11.6) — remapped once every
      // key map exists, below; stored raw here only for the ids.
      final pendingKeyJson = <(String, String, int, String)>[];
      for (final op in arr(nar['choiceOptions'])) {
        final talk = talkMap[op['talkId']];
        if (talk == null) continue;
        final jump = op['jumpId'];
        final id = await txn.rawInsert(
            'INSERT INTO story_choice_option (talk_ref, option_text, effect_kind, effect_text, jump_ref, option_order) '
            'VALUES (?,?,?,?,?,?)',
            <Object?>[talk, op['text'], op['effectKind'] ?? 'none', op['effectText'],
                      jump is int ? dlgMap[jump] : null, op['order'] ?? 0]);
        final cond = op['condition'];
        final ops = op['setOps'];
        if (cond is String && cond.isNotEmpty) pendingKeyJson.add(('story_choice_option', 'condition', id, cond));
        if (ops is String && ops.isNotEmpty) pendingKeyJson.add(('story_choice_option', 'set_ops', id, ops));
      }

      final bchpMap = <int, int>{};
      final pendingKeys = <(String, String, int, String)>[...pinLinks]; // single-key columns, remapped below
      for (final ch in arr(sect(p['author'])['chapters'])) {
        final m = mod(ch['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO book_chapter (module_ref, name, chapter_content, chapter_order, synopsis, status) VALUES (?,?,?,?,?,?)',
            <Object?>[m, ch['name'], ch['content'], ch['order'] ?? 0, ch['synopsis'], ch['status']]);
        final oldId = ch['id'];
        if (oldId is int) bchpMap[oldId] = id;
        final pov = ch['povKey'];
        if (pov is String && pov.isNotEmpty) pendingKeys.add(('book_chapter', 'pov_key', id, pov));
      }

      final cht = sect(p['chatscribe']);
      final chssMap = <int, int>{};
      for (final ses in arr(cht['sessions'])) {
        final m = mod(ses['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO chat_session (module_ref, name, session_order, create_at) '
            "VALUES (?,?,?,COALESCE(?,datetime('now')))",
            <Object?>[m, ses['name'], ses['order'] ?? 0, ses['createAt']]);
        final oldId = ses['id'];
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
        final id = await txn.rawInsert('INSERT INTO sketch_page (module_ref, name, page_order) VALUES (?,?,?)',
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

      // Diviner (§11.5) — before the key maps, which need divtMap; an
      // entry's linker_key is remapped with the other deferred single keys.
      final dvn = sect(p['diviner']);
      final divtMap = <int, int>{};
      final dveMap = <int, int>{};
      for (final t in arr(dvn['tables'])) {
        final m = mod(t['moduleId']);
        if (m == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO diviner_table (module_ref, name, dice, mode, display_order) VALUES (?,?,?,?,?)',
            <Object?>[m, t['name'], t['dice'], t['mode'] == 'join' ? 'join' : 'pick', t['order'] ?? 0]);
        final oldId = t['id'];
        if (oldId is int) divtMap[oldId] = id;
      }
      for (final e in arr(dvn['entries'])) {
        final table = divtMap[e['tableId']];
        if (table == null) continue;
        final id = await txn.rawInsert(
            'INSERT INTO diviner_entry (table_ref, weight, range_lo, range_hi, entry_text, display_order) VALUES (?,?,?,?,?,?)',
            <Object?>[table, e['weight'] ?? 1, e['lo'], e['hi'], e['text'], e['order'] ?? 0]);
        final oldId = e['id'];
        if (oldId is int) dveMap[oldId] = id;
        final lk = e['linkerKey'];
        if (lk is String && lk.isNotEmpty) pendingKeys.add(('diviner_entry', 'linker_key', id, lk));
      }
      for (final r in arr(dvn['rolls'])) {
        final table = divtMap[r['tableId']];
        if (table == null) continue;
        final entry = r['entryId'];
        await txn.rawInsert(
            "INSERT INTO diviner_roll (table_ref, dice_result, entry_ref, result_text, create_at) VALUES (?,?,?,?,COALESCE(?,datetime('now')))",
            <Object?>[table, r['dice'], entry is int ? dveMap[entry] : null, r['text'], r['createAt']]);
      }

      // --- notes (folder tree parents-first) ------------------------------
      // Before the key maps: a sketch pin, a Designer link or a relation can
      // point at a note, so note_<id> has to resolve from the first row that
      // uses a key (found by the shared snapshot fixture, Procress 12 part 0).
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
              <Object?>[nexusId, oldParent is int ? nfMap[oldParent] : null, f['name'], colorId(f['colorCode'])]);
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
            'INSERT OR IGNORE INTO note (nexus_ref, folder_ref, title, content, color, pinned) VALUES (?,?,?,?,?,?)',
            <Object?>[nexusId, folderId is int ? nfMap[folderId] : null, n['title'],
                      n['content'] ?? '', colorId(n['colorCode']), n['pinned'] ?? 0]);
        // OR IGNORE reports 0 when the row was skipped (a title collision):
        // leaving it out of the map stops anything pointing at a note that
        // was never inserted.
        final oldId = n['id'];
        if (id != 0 && oldId is int) noteMap[oldId] = id;
      }

      // The key maps come from the vendored ENTITY_KINDS (DraconDex-SDB):
      // every family that declares `sync` gets its map, by name, and one
      // that is missing throws instead of dropping rows. Registering them by
      // hand here is what dropped tlev_/sdlg_ endpoints on every pull (§11.1).
      final keyMaps = EntityKinds.keyMaps({
        'modMap': modMap, 'cobjMap': cobjMap, 'ctplMap': ctplMap, 'bchpMap': bchpMap,
        'chssMap': chssMap, 'evtMap': evtMap, 'dlgMap': dlgMap, 'noteMap': noteMap,
        'pageMap': pageMap, 'divtMap': divtMap, 'mevtMap': mevtMap,
      });
      // Key columns written before the maps were complete: a single key that
      // cannot be mapped is cleared; a JSON list entry that cannot is left out.
      for (final (table, col, id, key) in pendingKeys) {
        await txn.rawUpdate('UPDATE $table SET $col=? WHERE id=?', [remapEntityKey(key, keyMaps), id]);
      }
      for (final (table, col, id, json) in pendingKeyJson) {
        await txn.rawUpdate('UPDATE $table SET $col=? WHERE id=?', [remapKeyList(json, keyMaps), id]);
      }

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
            'INSERT INTO design_node (module_ref, shape, x, y, node_text, color, linker_key, w, h, read_order) '
            'VALUES (?,?,?,?,?,?,?,?,?,?)',
            <Object?>[m, n['shape'] ?? 'box', n['x'] ?? 0, n['y'] ?? 0, n['text'], n['color'], k,
                      n['w'], n['h'], n['readOrder']]);
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

      var droppedRelations = 0;
      final relations = arr(p['relations']);
      for (final rel in relations) {
        final fk = remapEntityKey(rel['fromKey'], keyMaps);
        final tk = remapEntityKey(rel['toKey'], keyMaps);
        // A Classifier relation FIELD's row names its field in rel_type
        // (ctpl_<id>, §11.3); a row whose field did not come across has lost
        // its owner and is dropped.
        final relType = rel['relType'];
        final isField = relType is String && RegExp(r'^ctpl_\d+$').hasMatch(relType);
        final rt = isField ? remapEntityKey(relType, keyMaps) : relType;
        if (fk == null || tk == null || (relType != null && relType != '' && rt == null)) {
          droppedRelations++;
          continue;
        }
        final validFrom = rel['validFrom'];
        final validTo = rel['validTo'];
        await txn.rawInsert(
            'INSERT OR IGNORE INTO entity_relation (nexus_ref, from_key, to_key, label, rel_type, directed, module_ref, valid_from, valid_to) '
            'VALUES (?,?,?,?,?,?,?,?,?)',
            <Object?>[
              nexusId, fk, tk, rel['label'], rt, rel['directed'] == 0 ? 0 : 1, mod(rel['moduleId']),
              validFrom is String ? dateMap[validFrom] : null, validTo is String ? dateMap[validTo] : null,
            ]);
      }

      // Page blocks (§12): item_key / source_key are entity keys, so they
      // wait for every map. '*' (the shared element layout) is not a key. An
      // element page whose element did not come across is dropped; a borrowed
      // component whose source did not is kept, pointing at nothing. Parents
      // first — a columns block before the blocks inside it.
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
          if (item != null && itemKey == null) continue;
          final src = b['sourceKey'];
          final id = await txn.rawInsert(
            'INSERT INTO page_block (module_ref, item_key, parent_id, block_type, component, source_key, '
            'config, content, prop_name, prop_type, block_order) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
            <Object?>[
              m, itemKey, oldParent is int ? blockMap[oldParent] : null,
              b['type'] ?? 'component', b['component'], src == null || src == '' ? null : remapEntityKey(src, keyMaps),
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

      // v5 Exhibitor scenes — after every key map exists. A node whose
      // entity did not come across keeps its place and label with the link
      // cleared, rather than vanishing from the user's layout.
      final exh = sect(p['exhibitor']);
      final enodeMap = <int, int>{};
      final enodeParents = <(int, int)>[];
      for (final n in arr(exh['nodes'])) {
        final m = mod(n['moduleId']);
        if (m == null) continue;
        final k = n['linkerKey'] == null ? null : remapEntityKey(n['linkerKey'], keyMaps);
        final id = await txn.rawInsert(
            'INSERT INTO exhibit_node (module_ref, node_type, linker_key, label, x, y, w, h, z, rotation, scale, locked, hidden, color, props) '
            'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            <Object?>[
              m, n['nodeType'] ?? 'entity', k, n['label'], n['x'] ?? 0, n['y'] ?? 0, n['w'], n['h'],
              n['z'] ?? 0, n['rotation'] ?? 0, n['scale'] ?? 1, _truthy(n['locked']) ? 1 : 0,
              _truthy(n['hidden']) ? 1 : 0, n['color'], remapExhibitProps(n['props'], ctplMap),
            ]);
        final oldId = n['id'];
        final parent = n['parentId'];
        if (oldId is int) {
          enodeMap[oldId] = id;
          if (parent is int) enodeParents.add((oldId, parent));
        }
      }
      for (final (id, pid) in enodeParents) {
        if (enodeMap.containsKey(pid)) {
          await txn.rawUpdate('UPDATE exhibit_node SET parent_id=? WHERE id=?', [enodeMap[pid], enodeMap[id]]);
        }
      }
      for (final v in arr(exh['views'])) {
        final m = mod(v['moduleId']);
        if (m == null) continue;
        final bg = v['bgLinkerKey'] == null ? null : remapEntityKey(v['bgLinkerKey'], keyMaps);
        await txn.rawInsert(
            'INSERT OR IGNORE INTO exhibit_view (module_ref, scale, tx, ty, bg_linker_key, grid, snap) VALUES (?,?,?,?,?,?,?)',
            <Object?>[m, v['scale'] ?? 1, v['tx'] ?? 0, v['ty'] ?? 0, bg, v['grid'] == 0 ? 0 : 1, _truthy(v['snap']) ? 1 : 0]);
      }

      // Templates carry no entity ids, so unlike relations they need no remap.
      // A name collision keeps the target's own copy.
      for (final ct in arr(p['calendarTemplates'])) {
        if (ct['name'] == null || ct['spec'] == null) continue;
        await txn.rawInsert(
            'INSERT OR IGNORE INTO calendar_template (nexus_ref, name, spec, builtin) VALUES (?,?,?,?)',
            <Object?>[nexusId, ct['name'], ct['spec'], _truthy(ct['builtin']) ? 1 : 0]);
      }
      // Presets are self-contained too (their spec holds colour CODES).
      for (final pr in arr(p['modulePresets'])) {
        if (pr['kind'] == null || pr['name'] == null || pr['spec'] is! String) continue;
        await txn.rawInsert('INSERT OR IGNORE INTO module_preset (nexus_ref, kind, name, spec) VALUES (?,?,?,?)',
            <Object?>[nexusId, pr['kind'], pr['name'], pr['spec']]);
      }

      // module_ui LAST: Wanderer's mapModule/timelineModule values are module
      // ids and have to go through modMap. Every other ui value is copied
      // verbatim — an entity id embedded in one (a filter definition) stays
      // stale, a documented limitation of the format on both sides.
      for (final u in arr(p['moduleUi'])) {
        final m = mod(u['moduleId']);
        if (m == null) continue;
        Object? value = u['value'];
        // A pre-v5 Connector's saved view maps the way the kind migration
        // maps it in place: graph -> the Scene, edge list -> Edges.
        if (u['key'] == 'activeView' && legacyKind[u['moduleId']] == 'connector') {
          value = u['value'] == 'edgelist' ? 'edges' : 'scene';
        }
        if (u['key'] == 'mapModule' || u['key'] == 'timelineModule') {
          final target = modMap[int.tryParse('${u['value']}')];
          if (target == null) continue;
          value = '$target';
        }
        await txn.rawInsert('INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,?)',
            <Object?>[m, u['key'], value]);
      }
      for (final e in legacyKind.entries) {
        if (e.value != 'connector') continue;
        await txn.rawInsert("INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,'activeView','scene')", [modMap[e.key]]);
        await txn.rawInsert("INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,'seedScene','1')", [modMap[e.key]]);
      }

      // A snapshot from an older app can carry modules under a non-Collector
      // — wrapped the same way the v5 rule wraps them on open.
      await normalizeModuleParents(txn);

      result = SnapshotApplyResult(
        ok: true,
        modules: modMap.length,
        notes: noteMap.length,
        relations: relations.length - droppedRelations,
        droppedRelations: droppedRelations,
        droppedPins: droppedPins,
        keyMaps: keyMaps,
      );
    });

    if (result.ok) await afterApply?.call(db, nexusId);
    return result;
  }

  /// Runs after a successful apply, outside its transaction: the wiki-link
  /// index is rebuilt, as EXE rebuilds it after every pull — a snapshot
  /// carries the texts, never the index.
  static Future<void> Function(Database db, int nexusId)? afterApply =
      (db, _) => WikiService.rebuildIndex(db);

  static bool _truthy(Object? v) => v == true || v == 1;

  /// A §7.9 card/table keeps the classifier_template ids it shows in props
  /// (fields / columns). Those ids are renumbered on apply like every other
  /// row; a field that did not come across drops out of the list.
  static Object? remapExhibitProps(Object? props, Map<int, int> tplMap) {
    if (props is! String) return props;
    Object? p;
    try {
      p = jsonDecode(props);
    } catch (_) {
      return props;
    }
    if (p is! Map) return props;
    for (final k in const ['fields', 'columns']) {
      final list = p[k];
      if (list is List) {
        p[k] = [for (final id in list) if (id is int && tplMap.containsKey(id)) tplMap[id]];
      }
    }
    return jsonEncode(p);
  }

  /// A JSON list of {key, …} (story_choice_option.condition / set_ops) with
  /// every key remapped; entries whose key cannot be mapped are left out.
  static String? remapKeyList(String json, Map<String, Map<int, int>> maps) {
    Object? list;
    try {
      list = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (list is! List) return null;
    final out = [
      for (final e in list)
        if (e is Map && remapEntityKey(e['key'], maps) != null) {...e, 'key': remapEntityKey(e['key'], maps)},
    ];
    return out.isEmpty ? null : jsonEncode(out);
  }

  /// `"module_12"` -> `"module_57"` through the per-kind maps; null when it
  /// cannot be mapped (a legacy kind, or a row this snapshot no longer holds).
  static String? remapEntityKey(Object? key, Map<String, Map<int, int>> maps) => EntityKinds.remap(key, maps);

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
    this.keyMaps = const {},
  });

  factory SnapshotApplyResult.failed(String code) => SnapshotApplyResult(ok: false, code: code);

  final bool ok;
  final String? code;
  final int modules;
  final int notes;
  final int relations;
  final int droppedRelations;
  final int droppedPins;

  /// old id -> new id per key family — the trash restores saved relations
  /// through them.
  final Map<String, Map<int, int>> keyMaps;
}
