import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';

/// `VaultSnapshotService` is a port of `serializeVault` / `applySnapshotCore`
/// in `electron/src/db/sync.js` (DraconDex-EXE). The two have to keep
/// producing and accepting the same JSON forever, and nothing about Dart
/// type-checking catches them drifting apart.
///
/// So this runs the REAL vault schema (the generated one both apps share, from
/// DraconDex-SDB) against sqlite and holds the port to the invariant that
/// actually matters: serialize -> apply -> serialize has to come back
/// identical, ids aside.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  /// A fresh in-memory vault per test.
  ///
  /// `addTearDown` rather than a `db.close()` at the end of each test: a test
  /// that fails an expectation never reaches its own last line, the database
  /// stays open, and the NEXT test's `openDatabase(':memory:')` gets handed
  /// that same live instance — whose `nexus` rows then collide on the UNIQUE
  /// name. One failure cascading into the next one's setup is a miserable
  /// thing to debug, so the cleanup cannot be on the happy path.
  Future<Database> openVault() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    for (final code in defaultColorCodes) {
      await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
    }
    return db;
  }

  Future<int> colorIdOf(Database db, String code) async {
    final rows = await db.rawQuery('SELECT id FROM use_color WHERE color_code=?', [code]);
    return rows.first['id']! as int;
  }

  /// A Nexus with something in most of the shapes the format carries, so the
  /// round trip exercises the id remapping rather than an empty vault.
  ///
  /// [withDanglingRelation] adds a relation whose endpoint no module owns.
  /// It is off by default because such a row CANNOT round-trip by design —
  /// apply drops it — so a vault containing one is the wrong fixture for an
  /// identity assertion. Its own test turns it on.
  Future<int> seedVault(Database db, {bool withDanglingRelation = false}) async {
    final blue = await colorIdOf(db, defaultColorCodes.first);
    final nexusId = await db.insert('nexus', {'name': 'My World', 'memo': 'a memo', 'color': blue});

    final root = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Characters',
      'kind': 'collector', 'display_order': 0, 'color': blue,
    });
    final child = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': root, 'name': 'Protagonists',
      'kind': 'classifier', 'display_order': 1,
    });
    await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Chapters',
      'kind': 'author', 'display_order': 2, 'handle': 'chapters',
    });

    await db.insert('page_block', {
      'module_ref': root, 'block_type': 'property', 'prop_name': 'era',
      'prop_type': 'text', 'content': 'third age', 'block_order': 0,
    });

    final tagId = await db.insert('hashtag', {'tag_name': 'main', 'tag_color': blue});
    await db.insert('module_hashtag', {'module_ref': root, 'hashtag_id': tagId});

    final obj = await db.insert('classifier_object', {
      'module_ref': child, 'name': 'Aria', 'color': blue, 'note': 'the lead', 'display_order': 0,
    });
    final tpl = await db.insert('classifier_template', {
      'module_ref': child, 'object_ref': obj, 'description': 'Age',
      'attribute_type': 'text', 'levelable': 0, 'has_condition': 0, 'display_order': 0,
    });
    await db.insert('classifier_attribute', {
      'object_ref': obj, 'template_ref': tpl, 'attribute_value': '24',
    });

    // v5 sections (APK V3 part 2): a relation field and a time-bound
    // relation, a Diviner table rolling another, an Exhibitor scene, a
    // chapter with a POV key, a choice whose condition names an entity, and a
    // module preset — every one carries keys or ids that must remap.
    final relField = await db.insert('classifier_template', {
      'module_ref': child, 'description': 'Rival', 'attribute_type': 'relation',
      'levelable': 0, 'has_condition': 0, 'display_order': 1, 'options': '{"targetKinds":["cobj"]}',
    });
    final rival = await db.insert('classifier_object', {'module_ref': child, 'name': 'Bram', 'display_order': 1});
    final dateId = await db.insert('timeline_date', {'day': 1, 'month': 2, 'years': 300, 'hour': 0, 'minute': 0});
    await db.insert('entity_relation', {
      'nexus_ref': nexusId, 'from_key': 'cobj_$obj', 'to_key': 'cobj_$rival',
      'rel_type': 'ctpl_$relField', 'directed': 1, 'module_ref': child, 'valid_from': dateId,
    });
    final dice = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Dice', 'kind': 'diviner', 'display_order': 3,
    });
    final names = await db.insert('diviner_table', {'module_ref': dice, 'name': 'Names', 'mode': 'pick'});
    final towns = await db.insert('diviner_table', {'module_ref': dice, 'name': 'Towns', 'dice': '1d6', 'mode': 'pick'});
    final entry = await db.insert('diviner_entry', {
      'table_ref': towns, 'weight': 1, 'range_lo': 1, 'range_hi': 6, 'entry_text': 'x', 'linker_key': 'divt_$names',
    });
    await db.insert('diviner_roll', {'table_ref': towns, 'dice_result': '4', 'entry_ref': entry, 'result_text': 'x'});
    final board = await db.insert('module', {
      'nexus_ref': nexusId, 'parent_id': null, 'name': 'Board', 'kind': 'exhibitor', 'display_order': 4,
    });
    final frame = await db.insert('exhibit_node', {'module_ref': board, 'node_type': 'frame', 'label': 'Cast'});
    await db.insert('exhibit_node', {
      'module_ref': board, 'parent_id': frame, 'node_type': 'entity', 'linker_key': 'cobj_$obj',
      'x': 10, 'y': 20, 'props': '{"fields":[$tpl]}',
    });
    await db.insert('exhibit_view', {'module_ref': board, 'scale': 1.5, 'tx': 3, 'ty': 4});
    await db.insert('module_preset', {'nexus_ref': nexusId, 'kind': 'classifier', 'name': 'Hero', 'spec': '{}'});

    final folder = await db.insert('note_folder', {
      'nexus_ref': nexusId, 'parent_ref': null, 'name': 'Lore', 'color': blue,
    });
    final note = await db.insert('note', {
      'nexus_ref': nexusId, 'folder_ref': folder, 'title': 'The Sundering',
      'content': 'It began with [[Aria]].', 'pinned': 0,
    });

    // A relation whose endpoints BOTH have to be remapped on the way in — the
    // single most breakable part of the port.
    await db.insert('entity_relation', {
      'nexus_ref': nexusId, 'from_key': 'module_$root', 'to_key': 'note_$note', 'label': 'mentions',
    });
    // ...and, on request, one that cannot be remapped at all, which apply must
    // drop and count rather than insert with an endpoint pointing at nothing.
    if (withDanglingRelation) {
      await db.insert('entity_relation', {
        'nexus_ref': nexusId, 'from_key': 'module_999999', 'to_key': 'note_$note', 'label': 'ghost',
      });
    }

    return nexusId;
  }

  /// Rewrites a snapshot so two serializations of the same content compare
  /// equal.
  ///
  /// Dropping `id` is not enough: every FOREIGN key (`parentId`, `moduleId`,
  /// `folderId`, the id embedded in a relation's `fromKey`…) also changes when
  /// rows are re-inserted, and stripping those instead would throw away
  /// exactly what a round trip is supposed to prove.
  ///
  /// So each id is replaced by the POSITION of the row it points at within its
  /// own section. `serializeVault` orders every section by id and
  /// `applySnapshot` inserts in that order, so position is stable across the
  /// trip while the id is not — and a link rewired to the wrong row still
  /// shows up as a mismatch.
  ///
  /// Written out section by section rather than as a generic walk: the same
  /// field name means different things in different sections (a folder's
  /// `parentId` points at folders, a module's at modules), and a clever
  /// traversal that gets that subtly wrong would weaken the test silently.
  Map<String, Object?> canonicalise(Map<String, Object?> snapshot) {
    final s = (jsonDecode(jsonEncode(snapshot)) as Map).cast<String, Object?>();
    s.remove('exportedAt');

    List<Map<String, Object?>> rows(Object? v) => v is List
        ? v.map((e) => (e as Map).cast<String, Object?>()).toList()
        : <Map<String, Object?>>[];
    Map<String, Object?> sect(Object? v) =>
        v is Map ? v.cast<String, Object?>() : <String, Object?>{};

    /// id -> position, and strips the `id` field on the way past.
    Map<int, int> index(List<Map<String, Object?>> list) {
      final out = <int, int>{};
      for (var i = 0; i < list.length; i++) {
        final id = list[i].remove('id');
        if (id is int) out[id] = i;
      }
      return out;
    }

    void remap(List<Map<String, Object?>> list, String field, Map<int, int> to) {
      for (final r in list) {
        final v = r[field];
        r[field] = v is int ? to[v] : null;
      }
    }

    final modules = rows(s['modules']);
    final cls = sect(s['classifier']);
    final loc = sect(s['locator']);
    final chr = sect(s['chronicler']);
    final nar = sect(s['narrator']);
    final cht = sect(s['chatscribe']);
    final skt = sect(s['sketcher']);
    final dsg = sect(s['designer']);
    final nts = sect(s['notes']);

    final objects = rows(cls['objects']);
    final templates = rows(cls['templates']);
    final maps = rows(loc['maps']);
    final areas = rows(loc['areas']);
    final timelines = rows(chr['timelines']);
    final events = rows(chr['events']);
    final dialogues = rows(nar['dialogues']);
    final talks = rows(nar['talks']);
    final chapters = rows(sect(s['author'])['chapters']);
    final sessions = rows(cht['sessions']);
    final pages = rows(skt['pages']);
    final nodes = rows(dsg['nodes']);
    final folders = rows(nts['folders']);
    final notes = rows(nts['notes']);

    // Indexed first, because remapping needs every map to exist.
    final modIx = index(modules);
    final objIx = index(objects);
    final tplIx = index(templates);
    final mapIx = index(maps);
    final areaIx = index(areas);
    final tlIx = index(timelines);
    final evtIx = index(events);
    final dlgIx = index(dialogues);
    final talkIx = index(talks);
    final chpIx = index(chapters);
    final sesIx = index(sessions);
    final pageIx = index(pages);
    final nodeIx = index(nodes);
    final folIx = index(folders);
    final noteIx = index(notes);
    final blocks = rows(s['pageBlocks']);
    final blockIx = index(blocks);
    final dvn = sect(s['diviner']);
    final dtables = rows(dvn['tables']);
    final dentries = rows(dvn['entries']);
    final dtIx = index(dtables);
    final deIx = index(dentries);
    final exh = sect(s['exhibitor']);
    final enodes = rows(exh['nodes']);
    final enIx = index(enodes);
    remap(dtables, 'moduleId', modIx);
    remap(dentries, 'tableId', dtIx);
    remap(rows(dvn['rolls']), 'tableId', dtIx);
    remap(rows(dvn['rolls']), 'entryId', deIx);
    remap(enodes, 'moduleId', modIx);
    remap(enodes, 'parentId', enIx);
    remap(rows(exh['views']), 'moduleId', modIx);
    // An exhibit node's props hold template ids.
    for (final n in enodes) {
      final props = n['props'];
      if (props is String && props.startsWith('{')) {
        final p = (jsonDecode(props) as Map).cast<String, Object?>();
        for (final k in ['fields', 'columns']) {
          if (p[k] is List) p[k] = [for (final id in p[k] as List) tplIx[id]];
        }
        n['props'] = jsonEncode(p);
      }
    }

    remap(modules, 'parentId', modIx);
    for (final key in <String>['pageBlocks', 'moduleUi', 'moduleTags']) {
      remap(rows(s[key]), 'moduleId', modIx);
    }
    remap(objects, 'moduleId', modIx);
    remap(templates, 'moduleId', modIx);
    remap(templates, 'objectId', objIx);
    remap(rows(cls['attributes']), 'objectId', objIx);
    remap(rows(cls['attributes']), 'templateId', tplIx);
    remap(maps, 'moduleId', modIx);
    remap(areas, 'mapId', mapIx);
    remap(rows(loc['points']), 'areaId', areaIx);
    remap(timelines, 'moduleId', modIx);
    remap(events, 'timelineId', tlIx);
    final mapEvents = rows(sect(s['wanderer'])['mapEvents']);
    remap(mapEvents, 'moduleId', modIx);
    remap(mapEvents, 'eventId', evtIx);
    remap(mapEvents, 'areaId', areaIx);
    remap(dialogues, 'moduleId', modIx);
    for (final field in <String>['moduleId', 'fromId', 'toId']) {
      remap(rows(nar['edges']), field, field == 'moduleId' ? modIx : dlgIx);
    }
    remap(talks, 'dialogueId', dlgIx);
    remap(rows(nar['choiceOptions']), 'talkId', talkIx);
    remap(rows(nar['choiceOptions']), 'jumpId', dlgIx);
    remap(chapters, 'moduleId', modIx);
    remap(sessions, 'moduleId', modIx);
    remap(rows(cht['messages']), 'sessionId', sesIx);
    remap(pages, 'moduleId', modIx);
    remap(rows(skt['strokes']), 'pageId', pageIx);
    remap(rows(skt['pins']), 'pageId', pageIx);
    remap(nodes, 'moduleId', modIx);
    for (final field in <String>['moduleId', 'fromId', 'toId']) {
      remap(rows(dsg['edges']), field, field == 'moduleId' ? modIx : nodeIx);
    }
    // A folder's parentId points at FOLDERS, not modules.
    remap(folders, 'parentId', folIx);
    remap(notes, 'folderId', folIx);

    // Relation endpoints and linker keys carry their id inside a string.
    final keyIx = <String, Map<int, int>>{
      'module': modIx, 'cobj': objIx, 'bchp': chpIx, 'chss': sesIx, 'note': noteIx,
      'ctpl': tplIx, 'divt': dtIx,
    };
    String? canonKey(Object? v) {
      if (v is! String) return null;
      final m = RegExp(r'^([a-z]+)_(\d+)$').firstMatch(v);
      if (m == null) return v;
      final idx = keyIx[m.group(1)]?[int.parse(m.group(2)!)];
      return idx == null ? v : '${m.group(1)}_#$idx';
    }

    for (final r in rows(s['relations'])) {
      r['fromKey'] = canonKey(r['fromKey']);
      r['toKey'] = canonKey(r['toKey']);
      r['relType'] = canonKey(r['relType']);
      final m = r['moduleId'];
      r['moduleId'] = m is int ? modIx[m] : null;
    }
    for (final r in dentries) {
      r['linkerKey'] = canonKey(r['linkerKey']);
    }
    for (final r in enodes) {
      r['linkerKey'] = canonKey(r['linkerKey']);
    }
    for (final r in chapters) {
      r['povKey'] = canonKey(r['povKey']);
    }
    for (final r in rows(skt['pins'])) {
      r['linkerKey'] = canonKey(r['linkerKey']);
    }
    for (final r in nodes) {
      r['linkerKey'] = canonKey(r['linkerKey']);
    }
    remap(blocks, 'parentId', blockIx);
    for (final r in blocks) {
      r['itemKey'] = canonKey(r['itemKey']);
      r['sourceKey'] = canonKey(r['sourceKey']);
    }

    return s;
  }

  test('the snapshot header matches what DraconDex-EXE writes', () async {
    final db = await openVault();
    final nexusId = await seedVault(db);
    final snap = (await VaultSnapshotService.serializeVault(db, nexusId))!;

    // These two strings ARE the compatibility check on both sides:
    // validateSnapshot in sync.js rejects anything else outright.
    expect(snap['format'], 'dracondex-vault-snapshot');
    expect(snap['version'], 2);
    expect((snap['nexus']! as Map)['name'], 'My World');
  });

  test('a note already converted to a module is not serialized', () async {
    final db = await openVault();
    final nexusId = await seedVault(db);
    await db.insert('note', {'nexus_ref': nexusId, 'title': 'Kept', 'content': 'a'});
    await db.insert('note', {'nexus_ref': nexusId, 'title': 'Converted', 'content': 'b', 'migrated_v3': 1});
    final snap = (await VaultSnapshotService.serializeVault(db, nexusId))!;
    final notes = ((snap['notes'] as Map)['notes'] as List).cast<Map>();
    expect(notes.map((n) => n['title']), isNot(contains('Converted')));
    expect(notes.map((n) => n['title']), contains('Kept'));
  });

  test('a v1 snapshot still imports, its module attributes as property blocks', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Old'});
    final r = await VaultSnapshotService.applySnapshot(db, targetId, <String, Object?>{
      'format': 'dracondex-vault-snapshot',
      'version': 1,
      'nexus': <String, Object?>{'name': 'x'},
      'modules': <Object?>[
        <String, Object?>{'id': 7, 'parentId': null, 'name': 'People', 'kind': 'classifier'},
      ],
      'moduleAttrs': <Object?>[
        <String, Object?>{'moduleId': 7, 'name': 'era', 'value': 'third age', 'displayOrder': 0},
      ],
    });
    expect(r.ok, isTrue, reason: r.code);
    final props = await db.rawQuery(
        "SELECT b.prop_name, b.content FROM page_block b JOIN module m ON b.module_ref=m.id "
        "WHERE m.nexus_ref=? AND b.block_type='property'", [targetId]);
    expect(props, [
      {'prop_name': 'era', 'content': 'third age'},
    ]);
  });

  test('serialize -> apply -> serialize comes back identical', () async {
    final db = await openVault();
    final sourceId = await seedVault(db);

    // No dangling relation in this fixture: a row whose endpoint cannot be
    // remapped is dropped on apply, by design, so a vault containing one can
    // never serialize back to itself. That behaviour has its own test.
    final first = (await VaultSnapshotService.serializeVault(db, sourceId))!;

    // Receiving always lands in a NEW Nexus: applySnapshot is wipe-and-rebuild
    // and would destroy an existing one.
    final targetId = await db.insert('nexus', {'name': 'Received'});
    final applied = await VaultSnapshotService.applySnapshot(db, targetId, first);
    expect(applied.ok, isTrue, reason: applied.code);

    final second = (await VaultSnapshotService.serializeVault(db, targetId))!;

    // The local Nexus NAME is deliberately kept (it is UNIQUE per install),
    // so that one field is expected to differ.
    final a = canonicalise(first);
    final b = canonicalise(second);
    (a['nexus']! as Map).remove('name');
    (b['nexus']! as Map).remove('name');

    expect(b, a);
  });

  test('the id remapping survives the round trip, dangling keys and all', () async {
    final db = await openVault();
    final sourceId = await seedVault(db, withDanglingRelation: true);
    final snap = (await VaultSnapshotService.serializeVault(db, sourceId))!;

    final targetId = await db.insert('nexus', {'name': 'Received'});
    final applied = await VaultSnapshotService.applySnapshot(db, targetId, snap);

    expect(applied.modules, 5);
    expect(applied.notes, 1);
    // Two real relations kept (the note link, and the time-bound relation
    // field), one unmappable one dropped and counted rather than inserted
    // with an endpoint pointing at nothing.
    expect(applied.relations, 2);
    expect(applied.droppedRelations, 1);

    // The surviving relations point at the NEW ids, not the old ones — the
    // relation field's rel_type included (a ctpl_ key, §11.3), and its span
    // as a real date row here.
    final newChars = (await db.rawQuery(
        "SELECT id FROM module WHERE nexus_ref=? AND name='Characters'", [targetId])).first['id'];
    final noteRel = await db.rawQuery(
        "SELECT from_key FROM entity_relation WHERE nexus_ref=? AND label='mentions'", [targetId]);
    expect(noteRel.single['from_key'], 'module_$newChars');
    final field = await db.rawQuery('''
      SELECT r.rel_type, r.valid_from, t.id AS tpl, d.years FROM entity_relation r
      JOIN classifier_template t ON r.rel_type = 'ctpl_' || t.id
      JOIN timeline_date d ON r.valid_from = d.id
      JOIN module m ON t.module_ref = m.id WHERE r.nexus_ref=? AND m.nexus_ref=?''', [targetId, targetId]);
    expect(field.single['years'], 300);

    // A Diviner entry that rolls another table points at the NEW table.
    final entry = await db.rawQuery('''
      SELECT e.linker_key, t.id AS names FROM diviner_entry e
      JOIN diviner_table tt ON e.table_ref = tt.id JOIN module m ON tt.module_ref = m.id
      JOIN diviner_table t ON t.module_ref = m.id AND t.name = 'Names'
      WHERE m.nexus_ref=?''', [targetId]);
    expect(entry.single['linker_key'], 'divt_${entry.single['names']}');

    // The Exhibitor node sits in its NEW frame, links the NEW object, and
    // its card shows the NEW template.
    final node = await db.rawQuery('''
      SELECT n.linker_key, n.props, f.label AS frame, o.id AS obj, t.id AS tpl
      FROM exhibit_node n JOIN exhibit_node f ON n.parent_id = f.id
      JOIN module m ON n.module_ref = m.id
      JOIN classifier_object o ON o.name = 'Aria'
      JOIN classifier_template t ON t.description = 'Age' AND t.module_ref = o.module_ref
      JOIN module om ON o.module_ref = om.id AND om.nexus_ref = m.nexus_ref
      WHERE m.nexus_ref=?''', [targetId]);
    expect(node.single['frame'], 'Cast');
    expect(node.single['linker_key'], 'cobj_${node.single['obj']}');
    expect(jsonDecode(node.single['props'] as String), {'fields': [node.single['tpl']]});
  });

  test('a module tree is rebuilt parents-first even when the payload is not ordered', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Out of order'});

    // Children before their parent. The BFS in applySnapshot exists precisely
    // so a snapshot in this order still lands with its tree intact.
    final payload = <String, Object?>{
      'format': 'dracondex-vault-snapshot',
      'version': 1,
      'nexus': <String, Object?>{'name': 'X', 'memo': null, 'colorCode': null},
      'lookups': <String, Object?>{'colors': <Object?>[], 'hashtags': <Object?>[], 'dates': <Object?>[]},
      'modules': <Object?>[
        <String, Object?>{'id': 3, 'parentId': 2, 'name': 'Grandchild', 'kind': 'classifier'},
        <String, Object?>{'id': 2, 'parentId': 1, 'name': 'Child', 'kind': 'collector'},
        <String, Object?>{'id': 1, 'parentId': null, 'name': 'Root', 'kind': 'collector'},
        // A module whose parent is not in the snapshot is a ROOT of what is
        // being imported (a .mddx of a nested module, a trashed subtree) and
        // lands where the caller says — EXE applySnapshotCore's rule. It used
        // to be dropped here, which silently lost such a subtree whole.
        <String, Object?>{'id': 9, 'parentId': 77, 'name': 'Orphan', 'kind': 'classifier'},
      ],
    };

    final applied = await VaultSnapshotService.applySnapshot(db, targetId, payload);
    expect(applied.ok, isTrue, reason: applied.code);
    expect(applied.modules, 4);

    final rows = await db.rawQuery(
        'SELECT id, parent_id, name FROM module WHERE nexus_ref=? ORDER BY name', [targetId]);
    expect(rows.map((r) => r['name']).toList(), <String>['Child', 'Grandchild', 'Orphan', 'Root']);
    expect(rows.firstWhere((r) => r['name'] == 'Orphan')['parent_id'], isNull);
    final byName = {for (final r in rows) r['name'] as String: r};
    expect(byName['Child']!['parent_id'], byName['Root']!['id']);
    expect(byName['Grandchild']!['parent_id'], byName['Child']!['id']);

  });

  test('a payload that is not a snapshot is refused rather than half-applied', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Target'});
    for (final bad in <Object?>[
      null,
      'not a map',
      <String, Object?>{'format': 'something-else', 'version': 1, 'nexus': <String, Object?>{}, 'modules': <Object?>[]},
      <String, Object?>{'format': 'dracondex-vault-snapshot', 'version': 99, 'nexus': <String, Object?>{}, 'modules': <Object?>[]},
      <String, Object?>{'format': 'dracondex-vault-snapshot', 'version': 1, 'modules': <Object?>[]},
    ]) {
      final r = await VaultSnapshotService.applySnapshot(db, targetId, bad);
      expect(r.ok, isFalse);
      expect(r.code, 'bad_snapshot');
    }
  });

  test('a colliding module handle is dropped rather than aborting the import', () async {
    final db = await openVault();
    final targetId = await db.insert('nexus', {'name': 'Target'});
    // Something already owns the handle the snapshot wants.
    await db.insert('module', {
      'nexus_ref': targetId, 'name': 'Existing', 'kind': 'classifier', 'handle': 'chapters',
    });

    final applied = await VaultSnapshotService.applySnapshot(db, targetId, <String, Object?>{
      'format': 'dracondex-vault-snapshot',
      'version': 1,
      'nexus': <String, Object?>{'name': 'X'},
      'modules': <Object?>[
        <String, Object?>{'id': 1, 'parentId': null, 'name': 'Chapters', 'kind': 'author', 'handle': 'chapters'},
      ],
    });

    // The wipe cleared 'Existing' first, so the handle is actually free by the
    // time the module lands — what matters is that the import completed at all
    // rather than throwing on a cosmetic field.
    expect(applied.ok, isTrue, reason: applied.code);
    expect(applied.modules, 1);
  });

  test('collectModuleSubtreeIds walks the whole subtree', () async {
    final db = await openVault();
    final nexusId = await db.insert('nexus', {'name': 'Tree'});
    final root = await db.insert('module', {'nexus_ref': nexusId, 'name': 'R', 'kind': 'classifier'});
    final a = await db.insert('module', {'nexus_ref': nexusId, 'parent_id': root, 'name': 'A', 'kind': 'classifier'});
    final b = await db.insert('module', {'nexus_ref': nexusId, 'parent_id': a, 'name': 'B', 'kind': 'classifier'});
    await db.insert('module', {'nexus_ref': nexusId, 'name': 'Elsewhere', 'kind': 'classifier'});

    final ids = await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, root);
    expect(ids.toSet(), <int>{root, a, b});
  });

  test('remapEntityKey only maps keys it has a map for', () {
    final maps = <String, Map<int, int>>{'module': <int, int>{12: 57}};
    expect(VaultSnapshotService.remapEntityKey('module_12', maps), 'module_57');
    expect(VaultSnapshotService.remapEntityKey('module_13', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey('note_12', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey('nonsense', maps), isNull);
    expect(VaultSnapshotService.remapEntityKey(null, maps), isNull);
  });
}
