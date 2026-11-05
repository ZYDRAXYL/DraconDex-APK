// Port Link 9.5 — clone both ways and sync, against a portable DraconDex
// laid out on disk exactly as the desktop's portable app leaves it (marker,
// app.ddx with absolute Windows paths against the root it last ran from,
// vaults/, DraconDex/<name>/ asset folders). The drive is a plain folder here;
// on a phone the same calls go through SAF.
import 'dart:convert';
import 'dart:io';

import 'package:dracondex/core/database/port_link_schema.dart';
import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/platform/saf.dart';
import 'package:dracondex/data/dao/port_link_dao.dart';
import 'package:dracondex/data/services/portlink/port_drive.dart';
import 'package:dracondex/data/services/portlink/portlink_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The drive's folder, as a plain directory.
class DirDrive implements PortDrive {
  final String root;
  DirDrive(this.root);
  String _p(String rel) => rel.isEmpty ? root : '$root/$rel';
  @override
  String get id => 'dir:$root';
  @override
  Future<SafEntry?> stat(String rel) async {
    final t = FileSystemEntity.typeSync(_p(rel));
    if (t == FileSystemEntityType.notFound) return null;
    final s = FileStat.statSync(_p(rel));
    return SafEntry(name: rel.split('/').last, dir: t == FileSystemEntityType.directory, size: s.size, mtime: s.modified.millisecondsSinceEpoch);
  }

  @override
  Future<List<SafEntry>?> list(String rel) async => Directory(_p(rel)).existsSync()
      ? [for (final e in Directory(_p(rel)).listSync()) (await stat('$rel/${e.uri.pathSegments.where((s) => s.isNotEmpty).last}'))!]
      : null;
  @override
  Future<bool> copyIn(String rel, String dest) async {
    if (!File(_p(rel)).existsSync()) return false;
    File(_p(rel)).copySync(dest);
    return true;
  }

  @override
  Future<bool> copyOut(String rel, String src) async {
    File('${_p(rel)}.tmp').parent.createSync(recursive: true);
    File(src).copySync('${_p(rel)}.tmp');
    File('${_p(rel)}.tmp').renameSync(_p(rel));
    return true;
  }

  @override
  Future<bool> mkdirs(String rel) async {
    Directory(_p(rel)).createSync(recursive: true);
    return true;
  }

  @override
  Future<bool> delete(String rel) async {
    if (File(_p(rel)).existsSync()) File(_p(rel)).deleteSync();
    return true;
  }
}

void main() {
  sqfliteFfiInit();
  final f = databaseFactoryFfi;
  late Directory tmp;
  late Database db;
  late DirDrive drive;
  late PortlinkService svc;
  const own = r'E:\DDX';

  Future<List<Map<String, Object?>>> q(Database d, String sql, [List<Object?> a = const []]) => d.rawQuery(sql, a);
  Future<T> onFile<T>(String path, Future<T> Function(Database) fn) async {
    final d = await f.openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
    try {
      return await fn(d);
    } finally {
      await d.close();
    }
  }

  String driveFile(int dId) => Directory('${drive.root}/novel-manager-data/vaults').listSync().map((e) => e.path).firstWhere((p) => p.endsWith('-$dId.ddx'));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('portsvc');
    // the portable app's folder: marker + app.ddx (it has run from E:\DDX)
    final root = '${tmp.path}/usb';
    Directory('$root/novel-manager-data/vaults').createSync(recursive: true);
    File('$root/dracondex-portable.json').writeAsStringSync(jsonEncode({'format': 'dracondex-portable', 'version': 1, 'driveUid': 'drive-x', 'dataDir': 'novel-manager-data'}));
    await onFile('$root/novel-manager-data/app.ddx', (r) async {
      await r.execute('CREATE TABLE app_setting (key TEXT PRIMARY KEY, value TEXT)');
      await r.execute('''CREATE TABLE nexus_file (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, memo TEXT, color_code TEXT,
        file_path TEXT UNIQUE, project_count INTEGER NOT NULL DEFAULT 0, counts_at TEXT, last_opened_at TEXT, missing INTEGER NOT NULL DEFAULT 0,
        locate_dir TEXT, create_at TEXT NOT NULL DEFAULT (datetime('now')), update_at TEXT NOT NULL DEFAULT (datetime('now')))''');
      await r.insert('app_setting', {'key': 'portableRoot', 'value': own});
      await r.insert('nexus_file', {'id': 4, 'name': 'Elsewhere', 'file_path': r'D:\other\x.ddx'}); // a row naming a file off the drive
    });
    drive = DirDrive(root);

    db = await f.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('PRAGMA foreign_keys = ON');
    for (final s in vaultCreateStatements) {
      await db.execute(s);
    }
    await ensurePortLinkTables(db);
    Directory('${tmp.path}/base').createSync();
    svc = PortlinkService(db, f, assetDir: (id) async => '${tmp.path}/docs/assets/$id', baseDir: () async => '${tmp.path}/base');
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<(int, int, int)> atlas() async {
    await db.insert('nexus', {'name': 'Other'}); // so Atlas's ids are not the drive's
    final nx = await db.insert('nexus', {'name': 'Atlas'});
    final m = await db.insert('module', {'nexus_ref': nx, 'name': 'Heroes', 'kind': 'classifier'});
    final a = await db.insert('classifier_object', {'module_ref': m, 'name': 'A'});
    final dir = Directory('${tmp.path}/docs/assets/$nx')..createSync(recursive: true);
    File('${dir.path}/map.png').writeAsBytesSync([1, 2, 3]);
    await db.insert('import_file', {'nexus_ref': nx, 'file_name': 'map.png', 'file_path': '${dir.path}/map.png', 'file_type': 'png', 'file_size': 3});
    return (nx, m, a);
  }

  test('readDrive: the portable app\'s Nexuses, paths made relative to its own root', () async {
    final info = (await svc.readDrive(drive))!;
    expect([info.driveUid, info.dataDir, info.ownRoot, info.sep], ['drive-x', 'novel-manager-data', own, r'\']);
    expect(info.rel(r'E:\DDX\novel-manager-data\vaults\a-1.ddx'), 'novel-manager-data/vaults/a-1.ddx');
    expect(info.rel(r'e:\ddx\DraconDex\Atlas'), 'DraconDex/Atlas', reason: 'a Windows path, any case');
    expect(info.rel(r'E:\DDX2\x'), isNull);
    expect(info.nexuses.single.missing, isTrue, reason: 'a row naming a file off the drive is not one we can open');
    expect(await svc.readDrive(DirDrive('${tmp.path}/nothing')), isNull);
  });

  test('clone to the drive: registered as the portable app registers it, only this Nexus, assets on the drive', () async {
    final (nx, _, _) = await atlas();
    final r = await svc.cloneToDrive(nx, drive);
    expect(r.ok, isTrue, reason: '${r.code} ${r.error}');
    final reg = await onFile('${drive.root}/novel-manager-data/app.ddx', (d) => q(d, 'SELECT id, name, file_path, locate_dir FROM nexus_file WHERE id = ?', [r.driveNexusId]));
    expect(reg.single['name'], 'Atlas');
    expect(reg.single['file_path'], '$own\\novel-manager-data\\vaults\\Atlas-${r.driveNexusId}.ddx');
    expect(reg.single['locate_dir'], '$own\\DraconDex\\Atlas');
    await onFile(driveFile(r.driveNexusId!), (v) async {
      expect(await q(v, 'SELECT id, name FROM nexus'), [{'id': r.driveNexusId, 'name': 'Atlas'}]);
      expect(await q(v, 'SELECT name FROM classifier_object'), [{'name': 'A'}]);
      expect(await q(v, 'SELECT file_path FROM import_file'), [{'file_path': '$own\\DraconDex\\Atlas\\map.png'}]);
      expect((await q(v, 'PRAGMA journal_mode')).single.values.single, 'delete', reason: 'the desktop cannot open a WAL vault');
    });
    expect(File('${drive.root}/DraconDex/Atlas/map.png').readAsBytesSync(), [1, 2, 3]);
    final l = (await PortLinkDao(db).linkOf(nx))!;
    expect([l.driveUid, l.driveNexusId, l.treeUri], ['drive-x', r.driveNexusId, drive.id]);
    expect(File(l.basePath).existsSync(), isTrue);
    expect((await svc.cloneToDrive(nx, drive)).code, 'already_linked');
    expect((await svc.sync(nx, drive)).unchanged, isTrue, reason: 'nothing changed anywhere');
  });

  test('clone from the drive: a new Nexus here with the drive\'s content and files, linked', () async {
    final (nx, _, _) = await atlas();
    final up = await svc.cloneToDrive(nx, drive);
    await svc.unlink(nx);
    final r = await svc.cloneFromDrive(drive, up.driveNexusId!);
    expect(r.ok, isTrue, reason: '${r.code} ${r.error}');
    expect(r.name, 'Atlas (2)', reason: '"Atlas" is taken on this phone');
    expect(await q(db, 'SELECT o.name FROM classifier_object o JOIN module m ON m.id = o.module_ref WHERE m.nexus_ref = ?', [r.nexusId]), [{'name': 'A'}]);
    final p = (await q(db, 'SELECT file_path FROM import_file WHERE nexus_ref = ?', [r.nexusId])).single['file_path'];
    expect(p, '${tmp.path}/docs/assets/${r.nexusId}/map.png');
    expect(File('$p').readAsBytesSync(), [1, 2, 3]);
    expect((await svc.sync(r.nexusId!, drive)).unchanged, isTrue);
    expect((await svc.cloneFromDrive(drive, up.driveNexusId!)).code, 'already_linked');
  });

  test("the owner's example: A renamed to B on the drive while this phone made C → B and C on both sides", () async {
    final (nx, m, a) = await atlas();
    final up = await svc.cloneToDrive(nx, drive);
    await onFile(driveFile(up.driveNexusId!), (v) => v.update('classifier_object', {'name': 'B'}));
    final c = await db.insert('classifier_object', {'module_ref': m, 'name': 'C'});
    final r = await svc.sync(nx, drive);
    expect(r.ok, isTrue, reason: '${r.code} ${r.error}');
    expect(await q(db, 'SELECT id, name FROM classifier_object WHERE module_ref = ? ORDER BY name', [m]), [{'id': a, 'name': 'B'}, {'id': c, 'name': 'C'}],
        reason: 'this phone keeps its own ids');
    expect(await onFile(driveFile(up.driveNexusId!), (v) => q(v, 'SELECT name FROM classifier_object ORDER BY name')), [{'name': 'B'}, {'name': 'C'}]);
    expect(await q(db, 'SELECT COUNT(*) n FROM nexus WHERE name = ?', ['Other']), [{'n': 1}]);
    expect((await svc.sync(nx, drive)).unchanged, isTrue, reason: "the result is the next sync's base");
  });

  test('the same field on both sides: asks, writes nothing, then takes the answer', () async {
    final (nx, _, a) = await atlas();
    final up = await svc.cloneToDrive(nx, drive);
    await onFile(driveFile(up.driveNexusId!), (v) => v.update('classifier_object', {'name': 'Drive'}));
    await db.update('classifier_object', {'name': 'Phone'}, where: 'id = ?', whereArgs: [a]);
    final before = File(driveFile(up.driveNexusId!)).readAsBytesSync();
    final r = await svc.sync(nx, drive);
    expect(r.code, 'needs_choice');
    expect(r.conflicts.single.col, 'name');
    expect([r.conflicts.single.local, r.conflicts.single.drive], ['Phone', 'Drive']);
    expect(File(driveFile(up.driveNexusId!)).readAsBytesSync(), before, reason: 'the drive is untouched');
    final r2 = await svc.sync(nx, drive, choices: {r.conflicts.single.key: 'drive'});
    expect(r2.ok, isTrue, reason: '${r2.code} ${r2.error}');
    expect(await q(db, 'SELECT name FROM classifier_object WHERE id = ?', [a]), [{'name': 'Drive'}]);
  });

  test('both sides made a row: both kept, this phone\'s keeps its local id, and a second sync is clean', () async {
    final (nx, m, _) = await atlas();
    final up = await svc.cloneToDrive(nx, drive);
    await onFile(driveFile(up.driveNexusId!), (v) async => v.insert('classifier_object', {'module_ref': (await q(v, 'SELECT id FROM module')).single['id'], 'name': 'Q'}));
    final p = await db.insert('classifier_object', {'module_ref': m, 'name': 'P'});
    expect((await svc.sync(nx, drive)).ok, isTrue);
    expect(await q(db, 'SELECT name FROM classifier_object WHERE id = ?', [p]), [{'name': 'P'}]);
    expect(await q(db, 'SELECT name FROM classifier_object WHERE module_ref = ? ORDER BY name', [m]), [{'name': 'A'}, {'name': 'P'}, {'name': 'Q'}]);
    await db.update('classifier_object', {'note': 'x'}, where: 'id = ?', whereArgs: [p]);
    expect((await svc.sync(nx, drive)).ok, isTrue);
    expect(await onFile(driveFile(up.driveNexusId!), (v) => q(v, "SELECT name FROM classifier_object WHERE note = 'x'")), [{'name': 'P'}],
        reason: 'the map followed P to its new drive id');
  });

  test('a drive file the portable app put on the drive: the asset it names comes across', () async {
    final (nx, _, _) = await atlas();
    final up = await svc.cloneToDrive(nx, drive);
    File('${drive.root}/DraconDex/Atlas/sub/new.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([9]);
    await onFile(driveFile(up.driveNexusId!), (v) => v.insert('import_file',
        {'nexus_ref': up.driveNexusId, 'file_name': 'new.png', 'file_path': '$own\\DraconDex\\Atlas\\sub\\new.png', 'file_type': 'png', 'file_size': 1}));
    expect((await svc.sync(nx, drive)).ok, isTrue);
    final p = (await q(db, "SELECT file_path FROM import_file WHERE file_name = 'new.png'")).single['file_path'];
    expect(p, '${tmp.path}/docs/assets/$nx/sub/new.png');
    expect(File('$p').readAsBytesSync(), [9]);
  });
}
