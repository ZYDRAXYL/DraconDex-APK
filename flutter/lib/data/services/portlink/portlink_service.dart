import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/platform/saf.dart';
import '../../dao/port_link_dao.dart';
import '../asset_pack.dart' show dirNameOf;
import 'port_drive.dart';
import 'portlink_codec.dart';
import 'portlink_files.dart';
import 'portlink_merge.dart';

/// What a Port Link call did. [code]: null when [ok]; otherwise why not —
/// `no_drive` · `never_ran` (the portable app has not started on this drive
/// yet, so its paths have no root) · `already_linked` · `not_linked` ·
/// `not_found` · `gone` (the drive's copy is missing) · `wrong_drive` ·
/// `name_taken` · `no_base` · `drive_changed` (the drive file changed while
/// we merged — run again) · `needs_choice` ([conflicts] says what to ask) ·
/// `map_broken` · `copy_failed`.
class PortResult {
  final bool ok;
  final String? code, linkUid, name, error;
  final int? driveNexusId, nexusId;
  final bool unchanged;
  final List<PortlinkConflict> conflicts;
  final Map<String, int> summary;
  const PortResult.ok({this.linkUid, this.driveNexusId, this.nexusId, this.name, this.unchanged = false, this.summary = const {}})
      : ok = true, code = null, conflicts = const [], error = null;
  const PortResult.fail(this.code, {this.conflicts = const [], this.error})
      : ok = false, linkUid = null, name = null, driveNexusId = null, nexusId = null, unchanged = false, summary = const {};
}

/// Port Link on Android (APP Plan.md Procress 32 part 9.5) — the same three
/// moves as EXE's portlink.js / portlink-merge.js, against the drive's
/// folder through [PortDrive]:
///
///   [cloneToDrive]   a Nexus here → a new Nexus in the portable app, linked
///   [cloneFromDrive] a drive Nexus → a new Nexus here, linked
///   [sync]           a linked pair → merged both ways (3-way, against the base)
///
/// The drive's layout is the portable app's own: `dracondex-portable.json`
/// (driveUid, dataDir) at the top; `<dataDir>/app.ddx` (nexus_file — paths
/// absolute, against the root it last ran from); `<dataDir>/vaults/*.ddx`;
/// each Nexus's asset folder under `DraconDex/<name>/`.
///
/// Asset rows name a file by an absolute path, which differs per side
/// (`<app docs>/assets/<id>/x.png` here, `E:\DDX\DraconDex\Atlas\x.png` on
/// the drive): the boundary rewrites them, so the merge compares like with
/// like. A file a row names that one side lacks is copied across.
/// ponytail: an asset edited in place on both sides keeps each side's bytes,
/// as on EXE.
class PortlinkService {
  final Database db;
  final DatabaseFactory factory;
  final Future<String> Function(int nexusId) assetDir;
  final Future<String> Function() baseDir;
  PortlinkService(this.db, this.factory, {Future<String> Function(int)? assetDir, Future<String> Function()? baseDir})
      : assetDir = assetDir ?? plAssetDir,
        baseDir = baseDir ?? plBaseDir;

  static const marker = 'dracondex-portable.json';
  static final _uidRe = RegExp(r'^[A-Za-z0-9-]{1,64}$');
  static final _colorRe = RegExp(r'^#[0-9a-fA-F]{3,8}$');

  PortLinkDao get _dao => PortLinkDao(db);
  PortlinkCodec get _codec => PortlinkCodec(db);

  // ── the drive ───────────────────────────────────────────────────────────

  /// null when [drive] holds no portable DraconDex.
  Future<DriveInfo?> readDrive(PortDrive drive) async {
    final tmp = await plTempDir();
    try {
      if (!await drive.copyIn(marker, '$tmp/m.json')) return null;
      final m = jsonDecode(await plRead('$tmp/m.json'));
      if (m is! Map || m['driveUid'] is! String || !_uidRe.hasMatch(m['driveUid'] as String)) return null;
      final dataDir = '${m['dataDir'] ?? 'novel-manager-data'}'.split('/').where((s) => s.isNotEmpty && s != '.' && s != '..').join('/');
      final reg = await _openRegistry(drive, dataDir, '$tmp/app.ddx', readOnly: true);
      if (reg == null) return DriveInfo(driveUid: m['driveUid'] as String, dataDir: dataDir, ownRoot: '', nexuses: const []);
      try {
        final own = await _ownRoot(reg);
        final info0 = DriveInfo(driveUid: m['driveUid'] as String, dataDir: dataDir, ownRoot: own ?? '', nexuses: const []);
        final out = <DriveNexus>[];
        for (final r in await reg.rawQuery('SELECT id, name, memo, color_code, file_path, locate_dir FROM nexus_file ORDER BY name COLLATE NOCASE')) {
          final fileRel = own == null ? null : info0.rel(r['file_path'] as String?);
          final color = '${r['color_code'] ?? ''}';
          out.add(DriveNexus(
            id: r['id']! as int,
            name: '${r['name'] ?? ''}',
            memo: r['memo'] as String?,
            color: _colorRe.hasMatch(color) ? color : null,
            fileRel: fileRel,
            locateRel: own == null ? null : info0.rel(r['locate_dir'] as String?),
            missing: fileRel == null || await drive.stat(fileRel) == null,
          ));
        }
        return DriveInfo(driveUid: info0.driveUid, dataDir: dataDir, ownRoot: info0.ownRoot, nexuses: out);
      } finally {
        await reg.close();
      }
    } catch (_) {
      return null;
    } finally {
      await plDelete(tmp);
    }
  }

  Future<Database?> _openRegistry(PortDrive drive, String dataDir, String dest, {bool readOnly = false}) async {
    if (!await drive.copyIn('$dataDir/app.ddx', dest)) return null;
    final reg = await factory.openDatabase(dest, options: OpenDatabaseOptions(readOnly: readOnly, singleInstance: false));
    final ok = (await reg.rawQuery("SELECT 1 FROM sqlite_master WHERE type='table' AND name='nexus_file'")).isNotEmpty;
    if (!ok) {
      await reg.close();
      return null;
    }
    return reg;
  }

  Future<String?> _ownRoot(Database reg) async {
    if ((await reg.rawQuery("SELECT 1 FROM sqlite_master WHERE type='table' AND name='app_setting'")).isEmpty) return null;
    final v = (await reg.rawQuery("SELECT value FROM app_setting WHERE key='portableRoot'")).firstOrNull?['value'];
    return v is String && v.isNotEmpty ? v : null;
  }

  // ── this phone → the drive ──────────────────────────────────────────────

  Future<PortResult> cloneToDrive(int nexusId, PortDrive drive) async {
    final info = await readDrive(drive);
    if (info == null) return const PortResult.fail('no_drive');
    if (info.ownRoot.isEmpty) return const PortResult.fail('never_ran');
    if (await _dao.linkOf(nexusId) != null) return const PortResult.fail('already_linked');
    final nx = (await db.query('nexus', where: 'id = ?', whereArgs: [nexusId])).firstOrNull;
    if (nx == null) return const PortResult.fail('not_found');
    final regRel = '${info.dataDir}/app.ddx';
    final regSig = Saf.sig(await drive.stat(regRel));
    final tmp = await plTempDir();
    String? wroteVault;
    try {
      // 1. the registry row, in a scratch copy of app.ddx
      final reg = await _openRegistry(drive, info.dataDir, '$tmp/app.ddx');
      if (reg == null) return const PortResult.fail('no_drive');
      late int dId;
      late String name, fileRel, locRel;
      try {
        final n = await _freeName('${nx['name']}', (c) async => (await reg.rawQuery('SELECT 1 FROM nexus_file WHERE name = ? COLLATE NOCASE', [c])).isNotEmpty);
        if (n == null) return const PortResult.fail('name_taken');
        name = n;
        dId = await reg.insert('nexus_file', {'name': name, 'memo': nx['memo']});
        fileRel = '${info.dataDir}/vaults/${_slug(name)}-$dId.ddx';
        final loc = await _freeName(dirNameOf(name), (c) async => await drive.stat('DraconDex/$c') != null);
        locRel = 'DraconDex/${loc ?? '${dirNameOf(name)}-$dId'}';
        await reg.update('nexus_file', {'file_path': info.abs(fileRel), 'locate_dir': info.abs(locRel)}, where: 'id = ?', whereArgs: [dId]);
        await reg.rawQuery('PRAGMA journal_mode = DELETE');
      } finally {
        await reg.close();
      }

      // 2. the vault, in the drive's ids, its asset rows pointed at the drive folder
      final out = '$tmp/v.ddx';
      final maps = await _codec.extract(nexusId: nexusId, driveNexusId: dId, outPath: out, l2d: const {}, factory: factory);
      final here = await assetDir(nexusId);
      await _edit(out, (f) async {
        await f.update('nexus', {'name': name}, where: 'id = ?', whereArgs: [dId]);
        await _repoint(f, here, info.abs(locRel), info.sep);
      });

      // 3. onto the drive: asset files, the vault, then the registry that names it
      await drive.mkdirs(locRel);
      await _copyAssets(out, drive, info, locRel, here);
      await drive.mkdirs('${info.dataDir}/vaults');
      if (!await drive.copyOut(fileRel, out)) return const PortResult.fail('copy_failed');
      wroteVault = fileRel;
      if (Saf.sig(await drive.stat(regRel)) != regSig) return const PortResult.fail('drive_changed');
      if (!await drive.copyOut(regRel, '$tmp/app.ddx')) return const PortResult.fail('copy_failed');
      wroteVault = null;

      // 4. the base and the link
      final base = '${await baseDir()}/${_uid()}.base.ddx';
      await plCopy(out, base);
      final linkUid = _uid();
      await db.transaction((txn) async {
        final dao = PortLinkDao(txn);
        await dao.insertLink(PortLink(linkUid: linkUid, nexusId: nexusId, treeUri: drive.id, driveUid: info.driveUid, driveNexusId: dId, basePath: base));
        await dao.replaceMaps(linkUid, {for (final e in maps.entries) if (e.key != 'nexus') e.key: e.value});
      });
      await _dao.markSynced(linkUid, basePath: base, localSig: await _codec.fingerprint(nexusId), driveSig: Saf.sig(await drive.stat(fileRel)));
      return PortResult.ok(linkUid: linkUid, driveNexusId: dId, nexusId: nexusId, name: name);
    } on PortlinkMapBroken {
      return const PortResult.fail('map_broken');
    } catch (e) {
      return PortResult.fail('copy_failed', error: '$e');
    } finally {
      if (wroteVault != null) await drive.delete(wroteVault); // not registered: nothing names it
      await plDelete(tmp);
    }
  }

  // ── the drive → this phone ──────────────────────────────────────────────

  Future<PortResult> cloneFromDrive(PortDrive drive, int driveNexusId) async {
    final info = await readDrive(drive);
    if (info == null) return const PortResult.fail('no_drive');
    if (info.ownRoot.isEmpty) return const PortResult.fail('never_ran');
    final dn = info.nexuses.where((n) => n.id == driveNexusId).firstOrNull;
    if (dn == null || dn.missing) return const PortResult.fail('not_found');
    if (await _dao.linkOfDrive(info.driveUid, dn.id) != null) return const PortResult.fail('already_linked');
    final name = await _freeName(dn.name, (c) async => (await db.query('nexus', columns: ['id'], where: 'name = ?', whereArgs: [c], limit: 1)).isNotEmpty);
    if (name == null) return const PortResult.fail('name_taken');
    final tmp = await plTempDir();
    int? id;
    String? base;
    try {
      final w = '$tmp/w.ddx';
      if (!await drive.copyIn(dn.fileRel!, w)) return const PortResult.fail('copy_failed');
      final driveSig = Saf.sig(await drive.stat(dn.fileRel!));
      base = '${await baseDir()}/${_uid()}.base.ddx';
      await plCopy(w, base);
      id = await db.insert('nexus', {'name': name, 'memo': dn.memo});
      final here = await assetDir(id);
      final loc = dn.locateRel == null ? null : info.abs(dn.locateRel!);
      if (loc != null) await _edit(w, (f) => _repoint(f, loc, here, '/'));
      final linkUid = _uid();
      await _dao.insertLink(PortLink(linkUid: linkUid, nexusId: id, treeUri: drive.id, driveUid: info.driveUid, driveNexusId: dn.id, basePath: base));
      await _codec.absorb(filePath: w, nexusId: id, driveNexusId: dn.id, d2l: const {}, factory: factory, linkUid: linkUid);
      await db.update('nexus', {'name': name}, where: 'id = ?', whereArgs: [id]); // this phone's free name, not the drive's
      if (dn.locateRel != null) await _copyAssets(base, drive, info, dn.locateRel!, here);
      await _dao.markSynced(linkUid, basePath: base, localSig: await _codec.fingerprint(id), driveSig: driveSig);
      final done = id;
      id = null;
      base = null;
      return PortResult.ok(linkUid: linkUid, driveNexusId: dn.id, nexusId: done, name: name);
    } catch (e) {
      return PortResult.fail('copy_failed', error: '$e');
    } finally {
      if (id != null) await db.delete('nexus', where: 'id = ?', whereArgs: [id]); // the link and every row go with it
      if (base != null) await plDelete(base);
      await plDelete(tmp);
    }
  }

  // ── both ways ───────────────────────────────────────────────────────────

  /// Merges a linked Nexus with its drive copy and writes the result to both.
  /// Nothing is written when a cell changed differently on both sides and
  /// [choices] does not answer it (`'table:id:col'` or `'*'` → `'local'` /
  /// `'drive'`): the result is `needs_choice` with the questions.
  Future<PortResult> sync(int nexusId, PortDrive drive, {Map<String, String> choices = const {}}) async {
    final link = await _dao.linkOf(nexusId);
    if (link == null) return const PortResult.fail('not_linked');
    final info = await readDrive(drive);
    if (info == null) return const PortResult.fail('no_drive');
    if (info.driveUid != link.driveUid) return const PortResult.fail('wrong_drive');
    final dn = info.nexuses.where((n) => n.id == link.driveNexusId).firstOrNull;
    if (dn == null || dn.missing) return const PortResult.fail('gone');
    if (!await plExists(link.basePath)) return const PortResult.fail('no_base');
    final fileRel = dn.fileRel!;
    final driveSig = Saf.sig(await drive.stat(fileRel));
    final localFp = await _codec.fingerprint(nexusId);
    if (localFp == link.localSig && driveSig == link.driveSig) return PortResult.ok(linkUid: link.linkUid, nexusId: nexusId, unchanged: true);

    final tmp = await plTempDir();
    String? newBase;
    try {
      final here = await assetDir(nexusId);
      final loc = dn.locateRel == null ? null : info.abs(dn.locateRel!);
      // L: this phone's Nexus in the drive's terms
      final l = '$tmp/l.ddx', w = '$tmp/w.ddx';
      final b = await factory.openDatabase(link.basePath, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
      final baseMax = <String, int>{};
      String? baseName;
      try {
        for (final t in await b.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")) {
          final n = '${t['name']}';
          final cols = await b.rawQuery('PRAGMA table_info("$n")');
          if (!cols.any((c) => c['name'] == 'id' && c['pk'] == 1)) continue;
          final m = (await b.rawQuery('SELECT MAX(id) m FROM "$n"')).first['m'];
          if (m is int) baseMax[n] = m;
        }
        baseName = (await b.rawQuery('SELECT name FROM nexus WHERE id = ?', [link.driveNexusId])).firstOrNull?['name'] as String?;
      } finally {
        await b.close();
      }
      final emaps = await _codec.extract(
          nexusId: nexusId, driveNexusId: link.driveNexusId, outPath: l, l2d: await _dao.allMaps(link.linkUid), baseMaxIds: baseMax, factory: factory);
      await _edit(l, (f) async {
        // a Nexus's name is each side's own (this phone may have called it "Atlas (2)")
        if (baseName != null) await f.update('nexus', {'name': baseName}, where: 'id = ?', whereArgs: [link.driveNexusId]);
        if (loc != null) await _repoint(f, here, loc, info.sep);
      });
      // W: the drive's file, L laid on top
      if (!await drive.copyIn(fileRel, w)) return const PortResult.fail('copy_failed');
      final r = await _merge(link.basePath, l, w, choices);
      if (r.conflicts.isNotEmpty) return PortResult.fail('needs_choice', conflicts: r.conflicts);

      // 1. the drive — unless it changed under us
      if (Saf.sig(await drive.stat(fileRel)) != driveSig) return const PortResult.fail('drive_changed');
      if (!await drive.copyOut(fileRel, w)) return const PortResult.fail('copy_failed');
      // 2. the new base
      newBase = '${await baseDir()}/${_uid()}.base.ddx';
      await plCopy(w, newBase);
      // 3. this phone: W in this phone's ids. The map follows every row the merge moved.
      final d2l = <String, Map<int, int>>{};
      for (final e in emaps.entries) {
        if (e.key == 'nexus') continue;
        final moved = r.renumbered[e.key] ?? const {};
        d2l[e.key] = {for (final x in e.value.entries) moved[x.value] ?? x.value: x.key};
      }
      final a = '$tmp/a.ddx';
      await plCopy(w, a);
      if (loc != null) await _edit(a, (f) => _repoint(f, loc, here, '/'));
      await _codec.absorb(filePath: a, nexusId: nexusId, driveNexusId: link.driveNexusId, d2l: d2l, factory: factory, linkUid: link.linkUid);
      // 4. asset files a merged row names that one side lacks
      if (dn.locateRel != null) await _copyAssets(w, drive, info, dn.locateRel!, here);
      // 5. the link
      await _dao.markSynced(link.linkUid, basePath: newBase, localSig: await _codec.fingerprint(nexusId), driveSig: Saf.sig(await drive.stat(fileRel)));
      await plDelete(link.basePath);
      newBase = null;
      return PortResult.ok(linkUid: link.linkUid, nexusId: nexusId, driveNexusId: link.driveNexusId, summary: r.summary);
    } on PortlinkMapBroken {
      return const PortResult.fail('map_broken');
    } catch (e) {
      return PortResult.fail('copy_failed', error: '$e');
    } finally {
      if (newBase != null) await plDelete(newBase);
      await plDelete(tmp);
    }
  }

  /// Stop syncing. Both copies stay.
  Future<void> unlink(int nexusId) async {
    final link = await _dao.linkOf(nexusId);
    if (link == null) return;
    await _dao.deleteLink(link.linkUid);
    await plDelete(link.basePath);
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  Future<PortlinkMergeResult> _merge(String base, String l, String w, Map<String, String> choices) async {
    final o = OpenDatabaseOptions(singleInstance: false);
    final bd = await factory.openDatabase(base, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    final ld = await factory.openDatabase(l, options: o), wd = await factory.openDatabase(w, options: o);
    try {
      final r = await mergeInto(bd, ld, wd, choices: choices);
      await wd.rawQuery('PRAGMA journal_mode = DELETE');
      return r;
    } finally {
      for (final d in [bd, ld, wd]) {
        await d.close();
      }
    }
  }

  /// Opens a scratch vault, runs [fn], leaves it in DELETE journal mode — the
  /// desktop's sqlite (node-sqlite3-wasm) cannot open a WAL file.
  Future<void> _edit(String path, Future<void> Function(Database) fn) async {
    final f = await factory.openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
    try {
      await fn(f);
      await f.rawQuery('PRAGMA journal_mode = DELETE');
    } finally {
      await f.close();
    }
  }

  /// Asset rows naming a file under [from] → the same file under [to].
  static Future<void> _repoint(Database f, String from, String to, String toSep) async {
    final fromT = from.replaceAll(RegExp(r'[\\/]+$'), ''), toT = to.replaceAll(RegExp(r'[\\/]+$'), '');
    final win = fromT.contains(r'\');
    for (final r in await f.rawQuery("SELECT id, file_path FROM import_file WHERE source_kind = 'file'")) {
      final p = '${r['file_path']}';
      final a = win ? p.toLowerCase() : p, b = win ? fromT.toLowerCase() : fromT;
      if (a.length <= b.length || !a.startsWith(b) || !'/\\'.contains(a[b.length])) continue;
      final rest = p.substring(fromT.length).split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
      if (rest.contains('..')) continue;
      await f.update('import_file', {'file_path': '$toT$toSep${rest.join(toSep)}'}, where: 'id = ?', whereArgs: [r['id']]);
    }
  }

  /// For every asset row of the (drive-form) vault [vault] under the drive
  /// folder [locRel]: the file copied to whichever side lacks it.
  Future<void> _copyAssets(String vault, PortDrive drive, DriveInfo info, String locRel, String here) async {
    final f = await factory.openDatabase(vault, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    final rels = <String>[];
    try {
      for (final r in await f.rawQuery("SELECT file_path FROM import_file WHERE source_kind = 'file'")) {
        final rel = info.rel('${r['file_path']}');
        if (rel != null && (rel == locRel || rel.startsWith('$locRel/'))) rels.add(rel.substring(locRel.length + 1));
      }
    } finally {
      await f.close();
    }
    for (final rel in rels) {
      try {
        final mine = '$here/$rel', theirs = '$locRel/$rel';
        final onDrive = await drive.stat(theirs) != null, local = await plExists(mine);
        if (local && !onDrive) {
          final dir = theirs.contains('/') ? theirs.substring(0, theirs.lastIndexOf('/')) : '';
          await drive.mkdirs(dir);
          await drive.copyOut(theirs, mine);
        } else if (onDrive && !local) {
          await plEnsureParent(mine);
          await drive.copyIn(theirs, mine);
        }
      } catch (_) {
        // one file that will not copy does not fail the sync
      }
    }
  }

  static Future<String?> _freeName(String base, Future<bool> Function(String) taken) async {
    for (var i = 1; i <= 99; i++) {
      final c = i == 1 ? base : '$base ($i)';
      if (!await taken(c)) return c;
    }
    return null;
  }

  /// EXE vaults.js vaultDefaultPath's slug.
  static String _slug(String name) {
    final s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '-');
    final t = s.length > 60 ? s.substring(0, 60) : s;
    return t.isEmpty ? 'nexus' : t;
  }

  static String _uid() {
    final r = Random.secure();
    final h = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
