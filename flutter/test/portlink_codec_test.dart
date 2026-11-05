// Port Link 9.3 — extract (one Nexus out of this app's single database into a
// vault file in the drive's ids) and absorb (back), with another Nexus beside
// it whose ids collide, a tag both use, and every kind of stored id: an FK, an
// entity key (entity_relation), module_ui mapModule (idRefs, id as TEXT),
// nexus_history.module_ref (idRefs).
import 'dart:io';

import 'package:dracondex/core/database/port_link_schema.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/port_link_dao.dart';
import 'package:dracondex/data/services/portlink/portlink_codec.dart';
import 'package:dracondex/data/services/portlink/portlink_refs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final f = databaseFactoryFfi;
  late Database db;
  late Directory tmp;
  late int other, atlas, mod, a, b, fire;

  Future<List<Map<String, Object?>>> q(DatabaseExecutor d, String sql, [List<Object?> args = const []]) => d.rawQuery(sql, args);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('portcodec');
    db = await f.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    await ensurePortLinkTables(db);
    // another Nexus first, so Atlas's ids are not 1, 2, 3…
    other = await db.insert('nexus', {'name': 'Other'});
    final om = await db.insert('module', {'nexus_ref': other, 'name': 'Theirs', 'kind': 'classifier'});
    for (var i = 0; i < 5; i++) {
      await db.insert('classifier_object', {'module_ref': om, 'name': 'o$i'});
    }
    fire = await db.insert('hashtag', {'tag_name': 'fire'});
    await db.insert('module_hashtag', {'module_ref': om, 'hashtag_id': fire});

    atlas = await db.insert('nexus', {'name': 'Atlas'});
    mod = await db.insert('module', {'nexus_ref': atlas, 'name': 'Heroes', 'kind': 'classifier'});
    a = await db.insert('classifier_object', {'module_ref': mod, 'name': 'A'});
    b = await db.insert('classifier_object', {'module_ref': mod, 'name': 'B'});
    await db.insert('entity_relation', {'nexus_ref': atlas, 'from_key': 'cobj_$a', 'to_key': 'cobj_$b', 'label': 'A knows B'});
    await db.insert('module_hashtag', {'module_ref': mod, 'hashtag_id': fire});
    await db.insert('module_ui', {'module_ref': mod, 'ui_key': 'mapModule', 'ui_value': '$mod'});
    await db.insert('nexus_history', {'nexus_ref': atlas, 'seq': 1, 'action': 'create', 'module_ref': mod, 'module_name': 'Heroes'});
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('the shape: 8 shared tables, the rest owned by a Nexus', () async {
    final s = await VaultShape.of(db);
    expect(s.shared, {'use_color', 'project_folder', 'timeline_date', 'relation_type', 'hashtag', 'symbol_collection', 'world_timeline_date', 'world_timeline_point'});
    expect(s.owned.contains('module_hashtag'), isTrue);
    expect(s.tables.any((t) => t.startsWith('port_')), isFalse, reason: "this install's own tables are not content");
  });

  test('rowsOf: this Nexus only, plus the shared rows it uses', () async {
    final rows = await PortlinkCodec(db).rowsOf(await VaultShape.of(db), atlas);
    expect(rows.ids('module'), {mod});
    expect(rows.ids('classifier_object'), {a, b});
    expect(rows.ids('hashtag'), {fire});
    expect(rows.joins['module_hashtag']!.map((r) => r['module_ref']), [mod]);
  });

  test('extract: the drive\'s ids, every stored id following', () async {
    final out = '${tmp.path}/l.ddx';
    final maps = await PortlinkCodec(db).extract(nexusId: atlas, driveNexusId: 7, outPath: out, l2d: const {}, factory: f);
    final l = await f.openDatabase(out, options: OpenDatabaseOptions(readOnly: true));
    try {
      expect(await q(l, 'SELECT id, name FROM nexus'), [{'id': 7, 'name': 'Atlas'}]);
      final dm = maps['module']![mod]!, da = maps['classifier_object']![a]!, db2 = maps['classifier_object']![b]!;
      expect(await q(l, 'SELECT id, nexus_ref FROM module'), [{'id': dm, 'nexus_ref': 7}]);
      expect((await q(l, 'SELECT id FROM classifier_object ORDER BY id')).map((r) => r['id']), [da, db2]);
      expect(await q(l, 'SELECT from_key, to_key FROM entity_relation'), [{'from_key': 'cobj_$da', 'to_key': 'cobj_$db2'}]);
      expect(await q(l, "SELECT ui_value FROM module_ui WHERE ui_key='mapModule'"), [{'ui_value': '$dm'}]);
      expect(await q(l, 'SELECT module_ref FROM nexus_history'), [{'module_ref': dm}]);
      expect(await q(l, 'SELECT tag_name FROM hashtag'), [{'tag_name': 'fire'}]);
      expect(await q(l, 'SELECT COUNT(*) n FROM classifier_object'), [{'n': 2}], reason: "the other Nexus's rows stay out");
    } finally {
      await l.close();
    }
  });

  test('a row made here after the link takes an id above everything the base holds', () async {
    final out = '${tmp.path}/l.ddx';
    final c = await db.insert('classifier_object', {'module_ref': mod, 'name': 'C'});
    final maps = await PortlinkCodec(db).extract(
      nexusId: atlas, driveNexusId: 7, outPath: out, factory: f,
      l2d: {'module': {mod: 1}, 'classifier_object': {a: 1, b: 2}},
      baseMaxIds: {'classifier_object': 40},
    );
    expect(maps['classifier_object']![c], 41);
    expect(maps['classifier_object']![a], 1, reason: 'mapped rows keep their drive id');
  });

  test('absorb a drive file as a new Nexus: fresh local ids, refs follow, the shared tag is matched not copied', () async {
    final out = '${tmp.path}/l.ddx';
    await PortlinkCodec(db).extract(nexusId: atlas, driveNexusId: 7, outPath: out, l2d: const {}, factory: f);
    final copy = await db.insert('nexus', {'name': 'Atlas (2)'});
    final l2d = await PortlinkCodec(db).absorb(filePath: out, nexusId: copy, driveNexusId: 7, d2l: const {}, factory: f);
    final m2 = (await q(db, 'SELECT id FROM module WHERE nexus_ref=?', [copy])).single['id']! as int;
    expect(m2, isNot(mod));
    final objs = await q(db, 'SELECT id, name FROM classifier_object WHERE module_ref=? ORDER BY name', [m2]);
    expect(objs.map((r) => r['name']), ['A', 'B']);
    expect(await q(db, "SELECT from_key, to_key FROM entity_relation WHERE nexus_ref=?", [copy]),
        [{'from_key': 'cobj_${objs[0]['id']}', 'to_key': 'cobj_${objs[1]['id']}'}]);
    expect(await q(db, "SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='mapModule'", [m2]), [{'ui_value': '$m2'}]);
    expect(await q(db, 'SELECT module_ref FROM nexus_history WHERE nexus_ref=?', [copy]), [{'module_ref': m2}]);
    expect(await q(db, 'SELECT COUNT(*) n FROM hashtag'), [{'n': 1}], reason: 'matched by tag_name');
    expect(await q(db, 'SELECT hashtag_id FROM module_hashtag WHERE module_ref=?', [m2]), [{'hashtag_id': fire}]);
    expect(l2d['module']![m2], isNotNull);
    expect((await q(db, 'SELECT name FROM nexus WHERE id=?', [copy])).single['name'], 'Atlas (2)', reason: "the drive's name is taken here — the local one stays");
    expect((await q(db, 'SELECT COUNT(*) n FROM classifier_object')).single['n'], 5 + 2 + 2, reason: 'Other and Atlas untouched');
  });

  test('round trip: extract, then absorb that file back — nothing changes, the map is written', () async {
    final codec = PortlinkCodec(db);
    final dao = PortLinkDao(db);
    await dao.insertLink(PortLink(linkUid: 'L', nexusId: atlas, treeUri: 't', driveUid: 'd', driveNexusId: 7, basePath: 'b'));
    final before = await codec.fingerprint(atlas);
    final otherBefore = await codec.fingerprint(other);
    final out = '${tmp.path}/l.ddx';
    final maps = await codec.extract(nexusId: atlas, driveNexusId: 7, outPath: out, l2d: const {}, factory: f);
    final d2l = {for (final e in maps.entries) e.key: {for (final x in e.value.entries) x.value: x.key}};
    await codec.absorb(filePath: out, nexusId: atlas, driveNexusId: 7, d2l: d2l, factory: f, linkUid: 'L');
    expect(await codec.fingerprint(atlas), before, reason: 'same rows, same ids, same values');
    expect(await codec.fingerprint(other), otherBefore);
    expect((await dao.localToDrive('L', 'classifier_object')), maps['classifier_object']);
    expect(await q(db, 'PRAGMA foreign_key_check'), isEmpty);
  });

  test('a map the Nexus no longer matches (replaced from a snapshot) refuses to extract', () async {
    final l2d = {'module': {mod: 1}, 'classifier_object': {a: 1, b: 2}};
    // a whole-Nexus import: every row back under a new id
    await db.delete('module', where: 'id = ?', whereArgs: [mod]);
    final m2 = await db.insert('module', {'nexus_ref': atlas, 'name': 'Heroes', 'kind': 'classifier'});
    await db.insert('classifier_object', {'module_ref': m2, 'name': 'A'});
    expect(
      () => PortlinkCodec(db).extract(nexusId: atlas, driveNexusId: 7, outPath: '${tmp.path}/x.ddx', l2d: l2d, factory: f),
      throwsA(isA<PortlinkMapBroken>()),
    );
  });

  test('a fingerprint changes with any edit and only then', () async {
    final codec = PortlinkCodec(db);
    final fp = await codec.fingerprint(atlas);
    expect(await codec.fingerprint(atlas), fp);
    await db.update('classifier_object', {'name': 'A2'}, where: 'id = ?', whereArgs: [a]);
    expect(await codec.fingerprint(atlas), isNot(fp));
    final fp2 = await codec.fingerprint(atlas);
    await db.update('classifier_object', {'name': 'o0b'}, where: 'module_ref <> ?', whereArgs: [mod]);
    expect(await codec.fingerprint(atlas), fp2, reason: "another Nexus's edit is not this one's");
  });
}
