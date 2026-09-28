import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/asset_pack.dart';
import 'package:dracondex/data/services/assets/asset_store.dart';
import 'package:dracondex/data/services/vault_snapshot_service.dart';

/// `.dxpack` (APP docs/ASSET-PACK.md): the snapshot, a manifest filing every
/// asset by moduleId, and the files under Assets/ laid out the way EXE's
/// folder mirror (db/mirror.js planMirror) will lay them out on disk.
void main() {
  sqfliteFfiInit();

  Future<Database> openVault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return db;
  }

  test('folder names follow the desktop mirror, clashes kept apart by id', () {
    expect(dirNameOf('a/b:c?'), 'a_b_c_');
    expect(dirNameOf('CON'), '_CON');
    expect(dirNameOf('trailing. '), 'trailing');
    expect(dirNameOf(''), '_');
    expect(dirNameOf('ตัวละคร'), 'ตัวละคร');
    // The same fixture EXE test/mirror.test.mjs plans.
    final plan = planFolders([
      {'id': 1, 'parent_id': null, 'name': 'World', 'kind': 'collector', 'display_order': 0},
      {'id': 2, 'parent_id': 1, 'name': 'Cast', 'kind': 'classifier', 'display_order': 0},
      {'id': 4, 'parent_id': 1, 'name': 'Maps', 'kind': 'collector', 'display_order': 2},
      {'id': 6, 'parent_id': 1, 'name': 'maps', 'kind': 'collector', 'display_order': 3},
      {'id': 5, 'parent_id': null, 'name': 'Top', 'kind': 'inspector', 'display_order': 0},
    ]);
    expect(plan, {1: 'World', 4: 'World/Maps', 6: 'World/maps (6)'});
  });

  test('a pack carries the tree, the files in their folders, and a manifest that files them', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'World'});
    final dao = ModuleDao(db);
    final world = await dao.createModule(nexusRef: nx, name: 'World', kind: ModuleKind.collector);
    final maps = await dao.createModule(nexusRef: nx, parentId: world, name: 'Maps', kind: ModuleKind.collector);
    final cast = await dao.createModule(nexusRef: nx, parentId: world, name: 'Cast', kind: ModuleKind.classifier);
    final elsewhere = await dao.createModule(nexusRef: nx, name: 'Elsewhere', kind: ModuleKind.collector);

    final tmp = await Directory.systemTemp.createTemp('dxpack');
    addTearDown(() => tmp.delete(recursive: true));
    Future<int> asset(String name, Uint8List bytes, int? moduleRef, {bool onDisk = true, Uint8List? proxy}) async {
      final f = File('${tmp.path}/$name');
      if (onDisk) await f.writeAsBytes(bytes);
      return db.insert('import_file', {
        'nexus_ref': nx,
        'file_name': name,
        'file_path': f.path,
        'file_type': name.split('.').last,
        'file_size': bytes.length,
        'module_ref': moduleRef,
        'sha256': sha256.convert(bytes).toString(),
        'proxy': proxy,
      });
    }

    final map = Uint8List.fromList(utf8.encode('map-bytes'));
    final face = Uint8List.fromList(utf8.encode('face-bytes'));
    final big = Uint8List.fromList(utf8.encode('the-original'));
    final thumb = Uint8List.fromList(utf8.encode('a-thumbnail'));
    final mapId = await asset('map.png', map, maps);
    final faceId = await asset('face.jpg', face, cast);
    await asset('cover.png', big, world, onDisk: false, proxy: thumb);
    await asset('lost.mp4', big, maps, onDisk: false);
    await asset('far.png', map, elsewhere);
    // Filing, the way the "Move to…" sheet does it.
    await AssetStore.setModule(db, faceId, cast);
    expect((await AssetStore.ofModule(db, maps)).map((a) => a.id), contains(mapId));

    final r = (await AssetPack.export(db, nx, moduleId: world))!;
    final zip = ZipDecoder().decodeBytes(r.bytes);
    final names = [for (final f in zip.files) f.name];
    expect(names.take(2), ['pack.json', 'snapshot.json']);
    expect(names.skip(2), unorderedEquals(['Assets/World/Maps/map.png', 'Assets/World/face.jpg', 'Assets/World/cover.png']));
    expect(r.files, 3);
    expect(r.missing, 1);

    final pack = jsonDecode(utf8.decode(zip.findFile('pack.json')!.content as List<int>)) as Map;
    expect(pack['format'], AssetPack.format);
    expect(pack['version'], 1);
    expect(pack['scope'], {'moduleId': world});
    final byName = {for (final a in pack['assets'] as List) (a as Map)['name']: a};
    expect(byName.keys, isNot(contains('far.png'))); // outside the scope
    expect(byName['map.png']!['moduleId'], maps);
    expect(byName['map.png']!['quality'], 'full');
    expect(byName['face.jpg']!['moduleId'], cast); // filed in the Classifier, sits in World/
    expect(byName['cover.png']!['quality'], 'proxy');
    expect(byName['lost.mp4']!['quality'], 'none');
    expect(byName['lost.mp4']!['zip'], isNull);
    expect(zip.findFile('Assets/World/Maps/map.png')!.content, map);

    final snap = jsonDecode(utf8.decode(zip.findFile('snapshot.json')!.content as List<int>)) as Map;
    expect(VaultSnapshotService.validate(snap), isTrue);
    expect([for (final m in snap['modules'] as List) (m as Map)['name']], unorderedEquals(['World', 'Maps', 'Cast']));

    // The desktop's own import test reads what this writes.
    final out = Platform.environment['DXPACK_OUT'];
    if (out != null) await File(out).writeAsBytes(r.bytes);
  });
}
