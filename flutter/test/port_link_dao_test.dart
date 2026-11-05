// Port Link 9.2 — this install's link tables: created beside the vault tables
// (and left alone by the schema upgrade), one link per Nexus and per drive
// Nexus, a local id ↔ drive id map per table that a replace swaps whole, and
// deleting a Nexus or a link taking its map with it.
import 'package:dracondex/core/database/port_link_schema.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/database/vault_upgrade.dart';
import 'package:dracondex/data/dao/port_link_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late int nexus;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    await ensurePortLinkTables(db);
    nexus = await db.insert('nexus', {'name': 'Atlas'});
  });
  tearDown(() => db.close());

  PortLink link(String uid, int nx, {int driveNexusId = 2}) => PortLink(
        linkUid: uid, nexusId: nx, treeUri: 'content://tree/DDX', driveUid: 'drive-1',
        driveNexusId: driveNexusId, basePath: '/data/portlink/$uid.base.ddx');

  test('created idempotently, and the schema upgrade leaves them alone', () async {
    await ensurePortLinkTables(db);
    await VaultUpgrade().run(db);
    final t = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'port_%' ORDER BY name"))
        .map((r) => r['name']).toList();
    expect(t, ['port_link', 'port_rowmap']);
    expect(VaultUpgrade.vendored.keys.where((k) => k.startsWith('port_')), isEmpty, reason: 'not vault tables');
  });

  test('one link per Nexus, one per drive Nexus', () async {
    final dao = PortLinkDao(db);
    await dao.insertLink(link('L1', nexus));
    expect((await dao.linkOf(nexus))!.linkUid, 'L1');
    expect((await dao.linkOfDrive('drive-1', 2))!.nexusId, nexus);
    final other = await db.insert('nexus', {'name': 'Borea'});
    await expectLater(dao.insertLink(link('L2', nexus, driveNexusId: 3)), throwsA(isA<DatabaseException>()), reason: 'same local Nexus');
    await expectLater(dao.insertLink(link('L3', other)), throwsA(isA<DatabaseException>()), reason: 'same drive Nexus');
    expect((await dao.listLinks()).length, 1);
  });

  test('the row map: per table, both directions, replaced whole', () async {
    final dao = PortLinkDao(db);
    await dao.insertLink(link('L1', nexus));
    await dao.replaceMaps('L1', {
      'module': {501: 10, 502: 11},
      'classifier_object': {900: 100},
    });
    expect(await dao.localToDrive('L1', 'module'), {501: 10, 502: 11});
    expect(await dao.driveToLocal('L1', 'module'), {10: 501, 11: 502});
    expect(await dao.allMaps('L1'), {'module': {501: 10, 502: 11}, 'classifier_object': {900: 100}});
    await dao.replaceMaps('L1', {'module': {501: 10}});
    expect(await dao.allMaps('L1'), {'module': {501: 10}}, reason: 'a replace leaves nothing of the old map');
    await expectLater(dao.replaceMaps('L1', {'module': {501: 10, 777: 10}}), throwsA(isA<DatabaseException>()),
        reason: 'two local rows cannot be the same drive row');
  });

  test('markSynced moves the base and the signatures', () async {
    final dao = PortLinkDao(db);
    await dao.insertLink(link('L1', nexus));
    await dao.markSynced('L1', basePath: '/data/portlink/new.base.ddx', localSig: 'fp:abc', driveSig: '8192:1762246800000');
    final l = (await dao.linkOf(nexus))!;
    expect([l.basePath, l.localSig, l.driveSig], ['/data/portlink/new.base.ddx', 'fp:abc', '8192:1762246800000']);
    expect(l.lastSyncAt, isNotNull);
  });

  test('deleting the link or the Nexus takes the map with it', () async {
    final dao = PortLinkDao(db);
    await dao.insertLink(link('L1', nexus));
    await dao.replaceMaps('L1', {'module': {501: 10}});
    await dao.deleteLink('L1');
    expect(await db.query('port_rowmap'), isEmpty);
    await dao.insertLink(link('L2', nexus));
    await dao.replaceMaps('L2', {'module': {501: 10}});
    await db.delete('nexus', where: 'id = ?', whereArgs: [nexus]);
    expect(await db.query('port_link'), isEmpty);
    expect(await db.query('port_rowmap'), isEmpty);
  });
}
